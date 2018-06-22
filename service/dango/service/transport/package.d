/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport;

public
{
    import dango.service.transport.core : ServerTransport;
}

private
{
    import dango.system.container;

    import dango.service.transport.middleware : HTTPMiddlewareContext;
    import dango.service.transport.http : HTTPServerTransport;
    import dango.service.transport.zeromq : ZeroMQServerTransport;
}


/**
 * Контекст DI транспортных уровней
 */
class TransportContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerNamed!(ServerTransport,
                HTTPServerTransport, HTTPServerTransport.NAME);
        container.registerNamed!(ServerTransport,
                ZeroMQServerTransport, ZeroMQServerTransport.NAME);

        container.registerContext!HTTPMiddlewareContext;
    }
}

