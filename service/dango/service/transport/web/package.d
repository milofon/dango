/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-04
 */

module dango.service.transport.web;

private
{
    import dango.system.container;
    import dango.system.component;

    import dango.web.server : WebApplicationServerFactory, WebApplicationServer;
    import dango.web.middlewares;
    import dango.web.controllers;

    import dango.service.transport.core : ServerTransport;
    import dango.service.transport.web.transport : WebServerTransportFactory;
}


/**
 * Контекст DI транспортных уровней
 */
class WebTransportContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerFactory!(WebApplicationServer, WebApplicationServerFactory);
        container.registerContext!WebMiddlewaresContext;
        container.registerContext!WebControllersContext;

        container.registerFactory!(ServerTransport, WebServerTransportFactory);
    }
}

