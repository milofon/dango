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

    import std.algorithm.iteration : filter, map;
    import std.algorithm.searching : canFind;
    import std.algorithm.sorting : sort;
    import std.format : fmt = format;
    import std.array : array;

    import uniconf.core : Config;
    import uniconf.core.exception : enforceConfig, ConfigNotFoundException;

    import vibe.http.server;
    import vibe.http.router : URLRouter, HTTPListener;
    import vibe.stream.tls : createTLSContext, TLSContext, TLSContextKind;

    import dango.system.properties : getNameOrEnforce, ConfigException;
    import dango.system.container;

    import dango.web.controller;
    import dango.system.logging;
}


/**
 * Интерфейс Web сервера
 */
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
        Config, ApplicationContainer)
{
    /**
     * Конструирует объект сервера
     */
    WebApplicationServer createServer(Config webConf, HTTPServerSettings settings,
            ApplicationContainer container);


    WebApplicationServer createComponent(Config webConf,
            ApplicationContainer container)
    {
        HTTPServerSettings settings = loadServiceSettings(webConf);
        return createServer(webConf, settings, container);

    }
}


/**
 * Класс веб сервера
 */
class HTTPApplicationServer : WebApplicationServer
{
    private
    {
        HTTPListener _listener;
        HTTPServerSettings _httpSettings;
        HTTPServerRequestHandler _handler;
    }


    this(HTTPServerRequestHandler handler, HTTPServerSettings settings)
    {
        this._httpSettings = settings;
        this._handler = handler;
    }


    void listen()
    {
        _listener = listenHTTP(_httpSettings, _handler);
        logInfo("Web Application Server start");
    }


    void shutdown()
    {
        _listener.stopListening();
        logInfo("Web Application Server stop");
    }
}


/**
 * Фабрика сервера с роутингом
 */
class URLRouterApplicationServerFactory : WebApplicationServerFactory
{
    override WebApplicationServer createServer(Config config, HTTPServerSettings settings,
            ApplicationContainer container)
    {
        URLRouter router = new URLRouter();

        string webName = config.getOrElse!string("name", "Undefined");
        logInfo("Configuring web application '%s'", webName);

        MiddlewareInfo[] middlewares;

        foreach (Config mdwConf; config.getArray("middleware"))
        {
            string mdwName = mdwConf.getNameOrEnforce(
                    "Not defined middleware name");

            auto mdwFactory = container.resolveNamed!(
                    ComponentFactoryAdapter!WebMiddleware)(mdwName);
            enforceConfig(mdwFactory !is null,
                    fmt!"Middleware '%s' not register"(mdwName));

            string label = mdwConf.getOrElse!string("label", mdwName);
            enforceConfig(!middlewares.canFind!((m) {
                        return m.label == label;
                    }), fmt!"Middleware %s already registered"(label));

            long ordering = mdwConf.getOrElse!long("order", 0);

            middlewares ~= MiddlewareInfo(ordering, mdwConf, mdwFactory, label);
        }

        foreach (Config ctrConf; config.getArray("controller"))
        {
            string ctrName = getNameOrEnforce(ctrConf,
                    "Not defined controller name");

            WebController ctrl;
            try
                ctrl = container.resolveNamedComponent!(WebController,
                        Config)(ctrName, ctrConf);
            catch (ResolveException e)
                throw new ConfigException(fmt!"Controller '%s' not register"(ctrName));

            auto ctrlMiddlewares = ctrConf.getArray("middlewares")
                    .map!(pm => pm.get!string);

            // проверка на наличие конфигураций
            foreach (string mdwLabel; ctrlMiddlewares)
            {
                enforceConfig(middlewares.canFind!((m) => m.label == mdwLabel),
                        fmt!"Middleware %s not found configuration"(mdwLabel));
            }

            auto activeMiddlewares = middlewares.filter!((mdwConf) {
                        bool def = mdwConf.config.getOrElse!bool("default", false);
                        return def || ctrlMiddlewares.canFind(mdwConf.label);
                    }).array;

            activeMiddlewares.sort!((a, b) => a.ordering > b.ordering);

            if (ctrl.enabled)
            {
                logInfo("Register controller: %s", ctrName);
                logInfo("  Activated middlewares: %s", activeMiddlewares
                        .map!(m => m.label));

                ctrl.registerChains((HTTPMethod method, string path, Chain ch) {
                    foreach (mdwInfo; activeMiddlewares)
                    {
                        WebMiddleware mdw = mdwInfo.create();
                        if (mdw.enabled)
                        {
                            ch.attachMiddleware(mdw);
                            mdw.registerHandlers(method, path, (HTTPMethod mdwMethod,
                                        string mdwPath, HTTPServerRequestDelegate mdwHdl) @safe {
                                router.match(mdwMethod, mdwPath, mdwHdl);
                            });
                        }
                    }

                    router.match(method, path, ch);
                });
            }
        }

        return new HTTPApplicationServer(router, settings);
    }
}



private:


struct MiddlewareInfo
{
    long ordering;
    Config config;
    ComponentFactoryAdapter!WebMiddleware factory;
    string label;

    WebMiddleware create()
    {
        return factory.create(config);
    }
}


/**
 * Функция стоит объект настроект http сервера по параметрам конфигурации
 * Params:
 *
 * config = Конфигурация
 */
HTTPServerSettings loadServiceSettings(Config config)
{
    HTTPServerSettings settings = new HTTPServerSettings();

    string host = config.getOrElse("host", "0.0.0.0");
    settings.bindAddresses = [host];

    auto port = config.get!long("port");
    if (port.isNull)
        throw new ConfigNotFoundException(config, "port");
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
        Config sslConfig = config.get!Config("ssl");
        settings.tlsContext = createTLSContextFrom(sslConfig);
    }

    return settings;
}


/**
 * Создание TLS контекста из конфигурации сервиса
 */
TLSContext createTLSContextFrom(Config sslConfig)
{
    TLSContext tlsCtx = createTLSContext(TLSContextKind.server);

    auto certChainFile = sslConfig.get!string("certificateChainFile");
    auto privateKeyFile = sslConfig.get!string("privateKeyFile");

    if (certChainFile.isNull)
        throw new ConfigNotFoundException(sslConfig, "certificateChainFile");

    if (privateKeyFile.isNull)
        throw new ConfigNotFoundException(sslConfig, "privateKeyFile");

    tlsCtx.useCertificateChainFile(certChainFile.get);
    tlsCtx.usePrivateKeyFile(privateKeyFile.get);

    return tlsCtx;
}

