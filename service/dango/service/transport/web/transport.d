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
    import dango.system.component;
    import dango.system.properties : getNameOrEnforce, configEnforce, getOrEnforce;


    import dango.web.server : WebApplicationServer;
    import dango.service.transport.core;
    import dango.service.transport.web.controller : RPCWebControllerFactory;
}


/**
 * Серверный транспорт использующий функционал HTTP
 */
class WebServerTransport : BaseServerTransport!("WEB")
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



class WebServerTransportFactory : BaseServerTransportFactory!WebServerTransport
{
    this(ApplicationContainer container)
    {
        super(container);
    }


    override WebServerTransport create(ServerProtocol protocol, Properties config)
    {
        auto rpcControllerFactory = new RPCWebControllerFactory(protocol, container);
        rpcControllerFactory.registerFactory();

        auto serverFactory = container.resolveFactory!WebApplicationServer;
        auto server = serverFactory.create(config);
        auto ret = new WebServerTransport(server);
        return ret;
    }
}

