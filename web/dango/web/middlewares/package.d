/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-03
 */

module dango.web.middlewares;

public
{
    import dango.web.middleware : WebMiddleware;
}

private
{
    import dango.system.container;
    import dango.web.middleware : registerMiddleware;

    import dango.web.middlewares.tokenauth;
    import dango.web.middlewares.baseauth;
    import dango.web.middlewares.cors;
}



class WebMiddlewaresContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerMiddleware!(TokenAuthWebMiddlewareFactory,
                TokenAuthWebMiddleware, "TOKENAUTH");
        container.registerMiddleware!(BaseAuthWebMiddlewareFactory,
                BaseAuthWebMiddleware, "BASEAUTH");
        container.registerMiddleware!(CorsWebMiddlewareFactory,
                CorsWebMiddleware, "CORS");
    }
}

