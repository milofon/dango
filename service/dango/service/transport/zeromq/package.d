/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-12-13
 */

module dango.service.transport.zeromq;

private
{
    import dango.system.inject;

    import dango.service.transport.zeromq.server;
    import dango.service.transport.zeromq.client;
}


/**
 * Контекст DI транспортного уровня ZeroMQ
 */
class ZeroMQTransportContext(string N) : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerNamedFactory!(ZeroMQServerTransport, N,
                ZeroMQServerTransportFactory);
        container.registerNamedFactory!(ZeroMQClientTransport, N,
                ZeroMQClientTransportFactory);
    }
}

