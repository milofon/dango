/**
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-30
 */

module dango.web.middlewares;

private
{
    import dango.web.plugin : WebServerContext, WebServerPlugin;

    import dango.web.middlewares.tokenauth;
    import dango.web.middlewares.baseauth;
    import dango.web.middlewares.cors;
}


/**
 * Основной контекст web приложения
 */
class BaseWebMiddlewaresContext : WebServerContext
{
    void registerPlugins(WebServerPlugin web) @safe
    {
        web.registerMiddleware!TokenAuthWebMiddlewareFactory("tokenauth");
        web.registerMiddleware!BaseAuthWebMiddlewareFactory("baseauth");
        web.registerMiddleware!CORSWebMiddlewareFactory("cors");
    }
}

