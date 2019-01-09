/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-04
 */

module dango.service.transport.web;

private
{
    import dango.system.inject;

    import dango.web.server : URLRouterApplicationServerFactory,
           HTTPApplicationServer;
    import dango.web.middlewares : WebMiddlewaresContext;
    import dango.web.controllers : WebControllersContext;
    import dango.web.controller : registerController;

    import dango.service.transport.web.transport;
    import dango.service.transport.web.controllers.rpc;
    import dango.service.transport.web.controllers.websocket;
}


/**
 * Контекст DI транспортного уровня WEB
 */
class WebTransportContext(string N) : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerNamedFactory!(HTTPApplicationServer, "ROUTER",
                URLRouterApplicationServerFactory);
        container.registerContext!WebMiddlewaresContext;
        container.registerContext!WebControllersContext;

        container.registerController!(RpcWebController,
                RpcWebControllerFactory, "RPC");
        container.registerController!(WebSocketController,
                WebSocketControllerFactory, "WS");

        container.registerNamedFactory!(WebServerTransport, N,
                WebServerTransportFactory);
        container.registerNamedFactory!(WebClientTransport, N,
                WebClientTransportFactory);
    }
}

