/**
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-29
 */

module dango.web;

public
{
    import dango.web.plugin : WebApplicationPlugin, WebPlugin, WebServerPlugin;
    import dango.web.server : WebApplicationServer;
}

private
{
    import dango.system.plugin : registerContext;
    import dango.web.plugin : WebServerContext;

    import dango.web.middlewares : BaseWebMiddlewaresContext;
    import dango.web.controllers : BaseWebControllersContext;
}


/**
 * Основной контекст web приложения
 */
class BaseWebComponentsContext : WebServerContext
{
    void registerPlugins(WebServerPlugin web) @safe
    {
        web.registerContext!BaseWebMiddlewaresContext;
        web.registerContext!BaseWebControllersContext;
    }
}

