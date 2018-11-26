/**
 * Модуль транспортного уровня на основе WebSocket
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-10-16
 */

module dango.service.transport.websocket;

private
{
    import vibe.http.server : HTTPServerSettings;

    import dango.system.container;
    import dango.web.server;

    import dango.service.transport.core;
}


class WebSocketServerTransport : ServerTransport
{
    private WebApplicationServer _server;


    this(WebApplicationServer server)
    {
        this._server = server;
    }


    void listen()
    {
        _server.listen();
    }


    void shutdown()
    {
        _server.shutdown();
    }
}


/**
 * Фабрика транспорта использующий функционал WebSocket
 */
class WebSocketServerTransportFactory : BaseServerTransportFactory
{
    ServerTransport createComponent(Config config, ApplicationContainer container,
            ServerProtocol protocol)
    {
        auto serverFactory = container.resolveFactory!(WebApplicationServer, Config,
                ApplicationContainer)("WS");
        auto server = serverFactory.create(config, container);

        return new WebSocketServerTransport(server);
    }
}


class WebSocketServer : WebApplicationServer
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
    }

    void shutdown()
    {

    }
}

/**
 * Фабрика сервера websocket
 */
class WebSocketServerFactory : WebApplicationServerFactory
{
    override WebApplicationServer createServer(Config config, HTTPServerSettings settings,
            ApplicationContainer container)
    {
        auto server = new WebSocketServer(settings);

        return server;
    }
}

