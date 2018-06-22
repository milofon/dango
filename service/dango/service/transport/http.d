/**
 * Модуль транспортного уровня на основе HTTP
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport.http;

public
{
    import proped : Properties;

    import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
}

private
{
    import core.time : dur;

    import std.format : fmt = format;

    import proped : PropertiesNotFoundException;

    import vibe.core.log;
    import vibe.http.router : URLRouter, HTTPListener;
    import vibe.stream.tls : createTLSContext, TLSContext, TLSContextKind;
    import vibe.stream.operations : readAll;
    import vibe.http.server;
    import vibe.http.client : HTTPClientSettings, requestHTTP, HTTPClientRequest;
    import vibe.inet.url : URL;

    import dango.system.properties : getNameOrEnforce, configEnforce, getOrEnforce;
    import dango.system.container : resolveNamed;

    import dango.service.transport.core;
    import dango.service.protocol.core;
}


/**
 * Интерфейс для Middleware HTTP
 * Позволяет производить предобработку входязих запросов
 */
interface HTTPMiddleware : Configurable!(Properties),
          HTTPServerRequestHandler, Named, Activated
{
    HTTPMiddleware setNext(HTTPMiddleware);

    void nextRun(HTTPServerRequest req, HTTPServerResponse res) @safe;
}


/**
  * Базовый класс для Middleware HTTP
  */
abstract class BaseHTTPMiddleware(string N)  : HTTPMiddleware
{
    enum NAME = N;

    protected
    {
        HTTPMiddleware _next;
        bool _enabled;
    }


    string name() @property
    {
        return NAME;
    }


    bool enabled() @property
    {
        return _enabled;
    }


    final void configure(Properties config)
    {
        _enabled = config.getOrElse!bool("enabled", false);
        middlewareConfigure(config);
    }


    HTTPMiddleware setNext(HTTPMiddleware next)
    {
        _next = next;
        return next;
    }


    void nextRun(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        if (_next !is null)
            _next.handleRequest(req, res);
    }


protected:


    void middlewareConfigure(Properties config);
}


/**
 * Серверный транспорт использующий функционал HTTP
 */
class HTTPServerTransport : BaseServerTransport!("HTTP")
{
    private
    {
        HTTPListener _listener;
        HTTPServerSettings _httpSettings;
        HTTPMiddleware headMiddleware;
    }


    override void transportConfigure(ApplicationContainer container, Properties config)
    {
        auto entrypoint = config.getOrElse!string("entrypoint", "/");
        _httpSettings = loadServiceSettings(config);
        HTTPMiddleware current;

        void pushMiddleware(HTTPMiddleware next)
        {
            if (current !is null)
                current.setNext(next);
            current = next;
            if (headMiddleware is null)
                headMiddleware = current;
        }

        foreach (Properties mdwConf; config.getArray("middleware"))
        {
            string mdwName = getNameOrEnforce(mdwConf,
                    "Not defined middleware name");

            auto mdw = container.resolveNamed!HTTPMiddleware(mdwName);
            configEnforce(mdw !is null, fmt!"Middleware '%s' not register"(mdwName));

            mdw.configure(mdwConf);

            if (mdw.enabled)
            {
                logInfo("Register middleware '%s' from '%s'", mdwName, mdw);
                pushMiddleware(mdw);
            }
        }

        if (auto restProto = cast(HTTPServerProtocol)protocol)
        {
            auto tail = new ProtoHandlerMiddleware(restProto);
            pushMiddleware(tail);
        }
        else if (auto binProto = cast(BinServerProtocol)protocol)
        {
            void handler(HTTPServerRequest req, HTTPServerResponse res)
            {
                auto data = binProto.handle(cast(immutable)req.bodyReader.readAll());
                res.writeBody(data);
            }

            auto router = new URLRouter;
            router.post(entrypoint, &handler);

            auto tail = new ProtoHandlerMiddleware(router);
            pushMiddleware(tail);
        }
        else
            throw new Exception("The type of the protocol is not supported by transport");
    }


    void listen()
    {
        _listener = listenHTTP(_httpSettings, headMiddleware);
    }


    void shutdown()
    {
        _listener.stopListening();
        logInfo("Transport HTTP Stop");
    }
}


/**
 * Клиентский транспорт использующий функционал HTTP
 */
class HTTPClientTransport : BaseClientTransport!("HTTP")
{
    private
    {
        HTTPClientSettings _settings;
        URL _entrypoint;
    }


    this(string entrypoint, HTTPClientSettings settings = null)
    {
        this(URL(entrypoint), settings);
    }


    this(URL entrypoint, HTTPClientSettings settings)
    {
        if (settings is null)
            settings = new HTTPClientSettings();
        initialize(entrypoint, settings);
    }


    void configure(Properties config)
    {
        auto settings = new HTTPClientSettings();
        string entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint for client transport");
        initialize(URL(entrypoint), settings);
    }


    Future!Bytes request(Bytes bytes)
    {
        // TODO: потокобезопосность
        import vibe.core.concurrency;
        return async({
                auto res = requestHTTP(_entrypoint, (scope HTTPClientRequest req) {
                        req.method = HTTPMethod.POST;
                        req.writeBody(bytes);
                    }, _settings);
                return cast(Bytes)res.bodyReader.readAll();
            });
    }


private:


    void initialize(URL entrypoint, HTTPClientSettings settings)
    {
        _entrypoint = entrypoint;
        _settings = settings;
    }
}


private:


class ProtoHandlerMiddleware : BaseHTTPMiddleware!"BASE"
{
    private HTTPServerRequestHandler _hdl;


    this(HTTPServerRequestHandler hdl)
    {
        this._hdl = hdl;
    }


    override void middlewareConfigure(Properties config) {}


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        _hdl.handleRequest(req, res);
    }
}


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

