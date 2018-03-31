/**
 * Модуль транспортного уровня на основе HTTP
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport.http;

private
{
    import std.exception : enforce;
    import std.format : fmt = format;

    import vibe.stream.operations : readAll;
    import vibe.inet.url : URL;
    import vibe.http.router;
    import vibe.http.client;
    import vibe.core.log;

    import dango.system.properties : getOrEnforce;
    import dango.controller.core : createOptionCORSHandler, handleCors;
    import dango.controller.http : loadServiceSettings;

    import dango.service.transport.core;
}


class HTTPServerTransport : ServerTransport
{
    private
    {
        HTTPListener _listener;
    }


    void listen(RpcServerProtocol protocol, Properties config)
    {
        auto router = new URLRouter();
        auto httpSettings = loadServiceSettings(config);
        string entrypoint = config.getOrElse!string("entrypoint", "/");

        void handler(HTTPServerRequest req, HTTPServerResponse res)
        {
            handleCors(req, res);
            ubyte[] data = protocol.handle(req.bodyReader.readAll());
            res.writeBody(data);
        }

        void handleError(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo err)
        {
            handleCors(req, res);
            if (err.debugMessage.length)
				res.writeBody("%s - %s\n\n%s\n\nInternal error information:\n%s"
                        .fmt(err.code, httpStatusText(err.code), err.message, err.debugMessage));
            else
                res.writeBody("%s - %s\n\n%s"
                        .fmt(err.code, httpStatusText(err.code), err.message));
        }

        httpSettings.errorPageHandler = &handleError;

        router.post(entrypoint, &handler);
        router.match(HTTPMethod.OPTIONS, entrypoint, createOptionCORSHandler());

        _listener = listenHTTP(httpSettings, router);
    }


    void shutdown()
    {
        _listener.stopListening();
        logInfo("Transport HTTP Stop");
    }
}



class HTTPClientConnection : ClientConnection
{
    private
    {
        URL _entrypoint;
        HTTPClientSettings _settings;
    }


    this(URL entrypoint, HTTPClientSettings settings)
    {
        _entrypoint = entrypoint;
        _settings = settings;
    }


    bool connected() @property
    {
        return true;
    }


    void connect() {}


    void disconnect() {}


    ubyte[] request(ubyte[] bytes)
    {
        import requests : postContent;
        return postContent(_entrypoint.toString, bytes, "application/binary").data;
        // auto res = requestHTTP(_entrypoint, (scope HTTPClientRequest req) {
        //         req.method = HTTPMethod.POST;
        //         req.writeBody(bytes);
        //     }, _settings);
        // return res.bodyReader.readAll();
    }
}



class HTTPClientConnectionPool : AsyncClientConnectionPool!HTTPClientConnection
{
    private
    {
        URL _entrypoint;
        HTTPClientSettings _settings;
    }


    this(URL entrypoint, HTTPClientSettings settings, uint size)
    {
        _entrypoint = entrypoint;
        _settings = settings;
        super(size);
    }


    HTTPClientConnection createNewConnection()
    {
        return new HTTPClientConnection(_entrypoint, _settings);
    }
}



class HTTPClientTransport : ClientTransport
{
    private
    {
        HTTPClientConnectionPool _pool;
    }


    this() {}


    this(URL entrypoint, HTTPClientSettings settings)
    {
        _pool = new HTTPClientConnectionPool(entrypoint, settings, 10);
    }


    void initialize(Properties config)
    {
        auto settings = new HTTPClientSettings();
        string entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint for client transport");
        _pool = new HTTPClientConnectionPool(URL(entrypoint), settings, 10);
    }


    ubyte[] request(ubyte[] bytes)
    {
        auto conn = _pool.getConnection();
        scope(exit) _pool.freeConnection(conn);
        return conn.request(bytes);
    }
}
