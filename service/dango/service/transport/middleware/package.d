/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-21
 */

module dango.service.transport.middleware;

public
{
    import dango.service.transport.http : HTTPMiddleware;
}


private
{
    import dango.system.container;

    import dango.service.transport.middleware.cors : CorsHTTPMiddleware;

    import dango.service.transport.middleware.baseauth : BaseAuthHTTPMiddleware;
    import dango.service.transport.middleware.tokenauth : TokenAuthHTTPMiddleware;
}



class HTTPMiddlewareContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerNamed!(HTTPMiddleware,
                CorsHTTPMiddleware, CorsHTTPMiddleware.NAME);
        container.registerNamed!(HTTPMiddleware,
                BaseAuthHTTPMiddleware, BaseAuthHTTPMiddleware.NAME);
        container.registerNamed!(HTTPMiddleware,
                TokenAuthHTTPMiddleware, TokenAuthHTTPMiddleware.NAME);
    }
}

