/**
 * Модуль реализации сервер web application
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-29
 */

module dango.web.server;

private
{
    import core.time : dur;

    import std.format : fmt = format;
    import std.typecons : Tuple;
    import std.algorithm.iteration : filter, map;
    import std.algorithm.searching : canFind;

    import proped : PropertiesNotFoundException;

    import vibe.core.log;
    import vibe.http.server;
    import vibe.http.router : URLRouter, HTTPListener;
    import vibe.stream.tls : createTLSContext, TLSContext, TLSContextKind;

    import dango.system.properties : getOrEnforce, getNameOrEnforce, configEnforce;
    import dango.system.container;

    import dango.web.controller;
    import dango.web.middleware;
}



alias MiddlewareConfig = Tuple!(
        Properties, "config",
        PostComponentFactory!WebMiddleware, "factory",
        string, "label");



interface WebApplicationServer
{
    /**
     * Запуск сервера
     */
    void listen();


    /**
     * Остановка сервера
     */
    void shutdown();
}


/**
 * Класс фабрики веб сервера
 */
abstract class WebApplicationServerFactory : ComponentFactory!(WebApplicationServer,
        ApplicationContainer)
{
    /**
     * Конструирует объект сервера
     */
    WebApplicationServer createServer(Properties webConf, HTTPServerSettings settings,
            ApplicationContainer container);


    WebApplicationServer createComponent(Properties webConf,
            ApplicationContainer container)
    {
        HTTPServerSettings settings = loadServiceSettings(webConf);
        return createServer(webConf, settings, container);

    }
}


/**
 * Класс веб сервера
 */
class RouterWebApplicationServer : WebApplicationServer
{
    private
    {
        HTTPListener _listener;
        HTTPServerSettings _httpSettings;
        URLRouter _router;
    }


    this(HTTPServerSettings settings)
    {
        this._router = new URLRouter();
        this._httpSettings = settings;
    }


    void listen()
    {
        _listener = listenHTTP(_httpSettings, _router);
        logInfo("Web Application Server start");
    }


    void shutdown()
    {
        _listener.stopListening();
        logInfo("Web Application Server stop");
    }


    void registerHandler(HTTPMethod method, string path, HTTPServerRequestHandler hdl)
    {
        _router.match(method, path, hdl);
    }


    void registerDelegate(HTTPMethod method, string path, HTTPServerRequestDelegate dg)
    {
        _router.match(method, path, dg);
    }
}


/**
 * Фабрика сервера с роутингом
 */
class RouterWebApplicationServerFactory : WebApplicationServerFactory
{
    override WebApplicationServer createServer(Properties webConf, HTTPServerSettings settings,
            ApplicationContainer container)
    {
        auto server = new RouterWebApplicationServer(settings);

        string webName = webConf.getOrElse!string("name", "Undefined");
        logInfo("Configuring web application %s", webName);
        MiddlewareConfig[] middlewares;

        foreach (Properties mdwConf; webConf.getArray("middleware"))
        {
            string mdwName = mdwConf.getNameOrEnforce(
                    "Not defined middleware name");

            auto mdwFactory = container.resolveFactory!WebMiddleware(mdwName);
            configEnforce(mdwFactory !is null,
                    fmt!"Middleware '%s' not register"(mdwName));

            string label = mdwConf.getOrElse!string("label", mdwName);
            configEnforce(!middlewares.canFind!((m) {
                        return m.label == label;
                    }), fmt!"Middleware %s already registered"(label));

            middlewares ~= MiddlewareConfig(mdwConf, mdwFactory, label);
        }

        foreach (Properties ctrConf; webConf.getArray("controller"))
        {
            string ctrName = getNameOrEnforce(ctrConf,
                    "Not defined controller name");

            auto ctrlFactory = container.resolveFactory!WebController(ctrName);
            configEnforce(ctrlFactory !is null,
                    fmt!"Controller '%s' not register"(ctrName));

            auto ctrlMiddlewares = ctrConf.getArray("middlewares")
                .map!(pm => pm.get!string);

            foreach (string mdwLabel; ctrlMiddlewares)
            {
                configEnforce(middlewares.canFind!((m) => m.label == mdwLabel),
                        fmt!"Middleware %s not found configuration"(mdwLabel));
            }

            auto activeMiddlewares = middlewares.filter!((mdwConf) {
                    bool def = mdwConf.config.getOrElse!bool("default", false);
                    return def || ctrlMiddlewares.canFind(mdwConf.label);
                });

            WebController ctrl = ctrlFactory.create(ctrConf);
            if (ctrl.enabled)
            {
                ctrl.registerChains((Chain ch) {
                    foreach (mdwConf; activeMiddlewares)
                    {
                        WebMiddleware mdw = mdwConf.factory.create(mdwConf.config);
                        if (mdw.enabled)
                        {
                            ch.attachMiddleware(mdw);
                            mdw.registerDelegates(ch, &server.registerDelegate);
                        }
                    }

                    server.registerHandler(ch.method, ch.path, ch);
                });
            }
        }

        return server;
    }
}


private:


/**
 * Функция стоит объект настроект http сервера по параметрам конфигурации
 * Params:
 *
 * config = Конфигурация
 */
HTTPServerSettings loadServiceSettings(Properties config)
{
    HTTPServerSettings settings = new HTTPServerSettings();

    string host = config.getOrElse("host", "0.0.0.0");
    settings.bindAddresses = [host];

    auto port = config.get!long("port");
    if (port.isNull)
        throw new PropertiesNotFoundException(config, "port");
    settings.port = cast(ushort)port.get;

    settings.options = HTTPServerOption.defaults;

    if ("hostName" in config)
        settings.hostName = config.get!string("hostName");

    if ("maxRequestTime" in config)
        settings.maxRequestTime = dur!"seconds"(config.get!long("maxRequestTime"));

    if ("keepAliveTimeout" in config)
        settings.keepAliveTimeout = dur!"seconds"(config.get!long("keepAliveTimeout"));

    if ("maxRequestSize" in config)
        settings.maxRequestSize = config.get!long("maxRequestSize");

    if ("maxRequestHeaderSize" in config)
        settings.maxRequestHeaderSize = config.get!long("maxRequestHeaderSize");

    if ("accessLogFormat" in config)
        settings.accessLogFormat = config.get!string("accessLogFormat");

    if ("accessLogFile" in config)
        settings.accessLogFile = config.get!string("accessLogFile");

    settings.accessLogToConsole = config.getOrElse("accessLogToConsole", false);

    if ("ssl" in config)
    {
        Properties sslConfig = config.sub("ssl");
        settings.tlsContext = createTLSContextFrom(sslConfig);
    }

    return settings;
}


/**
 * Создание TLS контекста из конфигурации сервиса
 */
TLSContext createTLSContextFrom(Properties sslConfig)
{
    TLSContext tlsCtx = createTLSContext(TLSContextKind.server);

    auto certChainFile = sslConfig.get!string("certificateChainFile");
    auto privateKeyFile = sslConfig.get!string("privateKeyFile");

    if (certChainFile.isNull)
        throw new PropertiesNotFoundException(sslConfig, "certificateChainFile");

    if (privateKeyFile.isNull)
        throw new PropertiesNotFoundException(sslConfig, "privateKeyFile");

    tlsCtx.useCertificateChainFile(certChainFile.get);
    tlsCtx.usePrivateKeyFile(privateKeyFile.get);

    return tlsCtx;
}

