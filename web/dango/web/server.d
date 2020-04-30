/**
 * Модуль реализации сервер web application
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-29
 */

module dango.web.server;

private
{
    import vibe.core.core;
    import vibe.http.server;
    import vibe.stream.tls : createTLSContext, TLSContext, TLSContextKind;

    import uniconf.core : UniConf;

    import dango.system.logging;
    import dango.system.properties;
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
 * Класс веб сервера
 */
class HTTPApplicationServer : WebApplicationServer
{
    private
    {
        HTTPListener[] _listeners;
        HTTPServerSettings _httpSettings;
        HTTPServerRequestHandler _handler;
    }


    this(HTTPServerSettings settings, HTTPServerRequestHandler handler) @safe
    {
        this._httpSettings = settings;
        this._handler = handler;
    }

    /**
     * Запуск сервера
     */
    void listen()
    {
        runWorkerTaskDist!(runWorker)(cast(shared)this);
        logInfo("HTTP Application Server start");
    }

    /**
     * Остановка сервера
     */
    void shutdown()
    {
        foreach (HTTPListener listener; _listeners)
            listener.stopListening();
        logInfo("HTTP Application Server stop");
    }


    private void runWorker() shared
    {
        HTTPServerSettings settings = cast(HTTPServerSettings)_httpSettings;
        settings.options = HTTPServerOption.reusePort;
        HTTPServerRequestHandler handler = cast(HTTPServerRequestHandler)_handler;
        _listeners ~= cast(shared)listenHTTP(settings, handler);
    }
}


/**
 * Функция стоит объект настроект http сервера по параметрам конфигурации
 * Params:
 *
 * config = Конфигурация
 */
HTTPServerSettings loadHTTPServerSettings(UniConf config) @safe
{
    import core.time : dur;
    import std.algorithm.iteration : map;
    import std.array : array;

    HTTPServerSettings settings = new HTTPServerSettings();

    auto host = config.getOrEnforce!UniConf("host", "Not defined host property");
    settings.bindAddresses = host.toSequence().map!((h) {
            return h.get!string;
        }).array;

    settings.port = config.getOrEnforce!ushort("port", "Not defined port property");
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
        UniConf sslConfig = config.get!UniConf("ssl");
        settings.tlsContext = createTLSContextFrom(sslConfig);
    }

    return settings;
}


/**
 * Создание TLS контекста из конфигурации сервиса
 */
TLSContext createTLSContextFrom(UniConf sslConfig) @safe
{
    TLSContext tlsCtx = createTLSContext(TLSContextKind.server);

    auto certChainFile = sslConfig.getOrEnforce!string("certificateChainFile",
            "Not defined certificateChainFile property");
    auto privateKeyFile = sslConfig.getOrEnforce!string("privateKeyFile",
            "Not defined privateKeyFile property");

    tlsCtx.useCertificateChainFile(certChainFile);
    tlsCtx.usePrivateKeyFile(privateKeyFile);

    return tlsCtx;
}


/**
 * Добаляет перфикс к url пути
 */
string joinInetPath(string prefix, string path) @safe
{
    import vibe.core.path : InetPath;

    auto parent = InetPath(prefix);
    auto child = InetPath(path);

    if (!parent.absolute)
        parent = InetPath("/") ~ parent;

    if (child.absolute)
    {
        auto childSegments = child.bySegment();
        childSegments.popFront();
        child = InetPath(childSegments);
    }

    if (!child.empty)
        parent ~= child;

    return parent.toString;
}

@("Should work joinInetPath method")
@safe unittest
{
    assert (joinInetPath("/", "api") == "/api");
    assert (joinInetPath("", "api") == "/api");
    assert (joinInetPath("/", "/api") == "/api");
    assert (joinInetPath("", "/api") == "/api");
}

