/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport;

public
{
    import dango.service.transport.core : ServerTransport, ClientTransport;
}

private
{
    import dango.system.container;

    import dango.service.transport.web : WebTransportContext;
    version (Dango_Service_ZeroMQ)
    import dango.service.transport.zeromq : ZeroMQTransportContext;
}


/**
 * Контекст DI транспортных уровней
 */
class TransportContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerContext!(WebTransportContext!"WEB");
        version (Dango_Service_ZeroMQ)
        container.registerContext!(ZeroMQTransportContext!"ZMQ");
    }
}

