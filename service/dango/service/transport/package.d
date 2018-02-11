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
    import poodinis : ApplicationContext, DependencyContainer, newInstance;
    import dango.system.container : registerByName;

    import dango.service.transport.http : HTTPServerTransport;
    import dango.service.transport.zeromq : ZeroMQServerTransport;
}


class TransportContext : ApplicationContext
{
    override void registerDependencies(shared(DependencyContainer) container)
    {
        container.registerByName!(ServerTransport, HTTPServerTransport)("http").newInstance();
        container.registerByName!(ServerTransport, ZeroMQServerTransport)("zmq").newInstance();
    }
}
