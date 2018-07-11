/**
 * Модуль транспортного уровня на основе Web application
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-04
 */

module dango.service.transport.web.transport;

private
{
    import dango.system.container;
    import dango.system.properties : getNameOrEnforce, configEnforce, getOrEnforce;

    import dango.web.controller : WebController;
    import dango.web.server : WebApplicationServer;

    import dango.service.transport.core;
    import dango.service.transport.web.controller;
}


/**
 * Серверный транспорт использующий функционал HTTP
 */
class WebServerTransport : ServerTransport
{
    private
    {
        WebApplicationServer _server;
    }


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



class WebServerTransportFactory : BaseServerTransportFactory!"WEB"
{
    ServerTransport createComponent(Properties config, ApplicationContainer container,
            ServerProtocol protocol)
    {
        auto rpcFactory = new RpcWebControllerFactory(protocol);
        container.registerFactory!(RpcWebControllerFactory,
                RpcWebController)(rpcFactory);

        auto serverFactory = container.resolveFactory!(WebApplicationServer,
                ApplicationContainer);
        auto server = serverFactory.create(config, container);

        return new WebServerTransport(server);
    }
}

