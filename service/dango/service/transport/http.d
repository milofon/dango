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
    import vibe.stream.operations : readAll;
    import vibe.http.router;
    import vibe.core.log;

    import dango.controller.core : createOptionCORSHandler, handleCors;
    import dango.controller.http : loadServiceSettings;
    import dango.service.transport.core;
}


class HTTPTransport : Transport
{
    private
    {
        Dispatcher _dispatcher;
        HTTPListener _listener;
    }


    void listen(Dispatcher dispatcher, Properties config)
    {
        _dispatcher = dispatcher;

        auto router = new URLRouter();
        auto httpSettings = loadServiceSettings(config);
        string entrypoint = config.getOrElse!string("entrypoint", "/");

        router.post(entrypoint, &mainHandler);
        router.match(HTTPMethod.OPTIONS, entrypoint, createOptionCORSHandler());

        _listener = listenHTTP(httpSettings, router);
    }


    void shutdown()
    {
        _listener.stopListening();
        logInfo("Transport HTTP Stop");
    }

private:

    void mainHandler(HTTPServerRequest req, HTTPServerResponse res)
    {
        handleCors(req, res);
        ubyte[] data = _dispatcher.handle(req.bodyReader.readAll());
        res.writeBody(data);
    }
}
