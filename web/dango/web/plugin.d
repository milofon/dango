/**
 * Реализация плагина для содания веб приложения
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-29
 */

module dango.web.plugin;

public
{
    import dango.web.server : WebApplicationServer;
}

private
{
    import std.algorithm.searching : canFind;
    import std.algorithm.iteration : filter, map;
    import std.algorithm.sorting : sort;
    import std.format : fmt = format;
    import std.array : array;
    import std.uni : toUpper;

    import vibe.http.router : URLRouter;

    import dango.inject;
    import dango.system.application : Application, UniConf;
    import dango.system.properties;
    import dango.system.exception;
    import dango.system.logging;
    import dango.system.plugin;

    import dango.web.middleware;
    import dango.web.controller;
    import dango.web.server;
}


/**
 * Плагин поддерживающий обработку запросов
 */
interface WebPlugin : Plugin
{
    /**
     * Регистрация сервера
     */
    void registerServer(void delegate(WebApplicationServer) dg) @safe;
}


/**
 * Реализация демона для запуска web приложения
 */
class WebApplicationPlugin : DaemonPlugin, PluginContainer!WebPlugin
{
    private
    {
        WebApplicationServer[] _servers;
        WebPlugin[] _plugins;
    }


    /**
     * Свойство возвращает наименование плагина
     */
    string name() pure @safe nothrow
    {
        return "WEB";
    }

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() pure nothrow @safe
    {
        return SemVer(0, 0, 1);
    }

    /**
     * Запуск процесса
     */
    int startDaemon()
    {
        foreach (plugin; _plugins)
            plugin.registerServer((server) {
                    _servers ~= server;
                });

        foreach (WebApplicationServer server; _servers)
            server.listen();

        return 0;
    }

    /**
     * Остановка процесса
     *
     * Params:
     * exitStatus = Код завершения приложения
     */
    int stopDaemon(int exitStatus)
    {
        foreach (WebApplicationServer server; _servers)
            server.shutdown();
        return exitStatus;
    }

    /**
     * Регистрация плагина
     * Params:
     * plugin = Плагин для регистрации
     */
    void collectPlugin(WebPlugin plugin) @safe nothrow
    {
        _plugins ~= plugin;
    }
}


/**
 * Контекст регистрации компонентов контроллера
 */
alias WebServerContext = PluginContext!(WebServerPlugin);


/**
 * Плагин сервера с роутингом
 */
class WebServerPlugin : WebPlugin
{
    private 
    {
        WebControllerFactory[string] _controllers;
        WebMiddlewareFactory[string] _middlewares;
        DependencyContainer _container;
        UniConf _config;
    }


    /**
     * Main constructor
     */
    @Inject
    this(Application application)
    {
        this._container = application.getContainer();
        this._config = application.getConfig();
    }

    /**
     * Свойство возвращает наименование плагина
     */
    string name() pure @safe nothrow
    {
        return "Web Server";
    }

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() pure nothrow @safe
    {
        return SemVer(0, 0, 1);
    }

    /**
     * Регистрация сервера
     */
    void registerServer(void delegate(WebApplicationServer) @safe dg) @safe
    {
        auto webConfigs = _config.getOrEnforce!UniConf("web",
                "Not found web application configurations");

        foreach (UniConf webConf; webConfigs.toSequence())
        {
            if (webConf.getOrElse("enabled", false))
            {
                if (auto server = createServer(webConf))
                    dg(server);
            }
        }
    }

    /**
     * Регистрация middleware
     */
    void registerMiddleware(M : WebMiddleware)(string name) @safe
    {
        alias MF = ComponentFactoryCtor!(WebMiddleware, M, UniConf);
        registerMiddleware!(MF)(name);
    }

    /**
     * Регистрация middleware с использованием фабрики
     */
    void registerMiddleware(MF : WebMiddlewareFactory)(string name) @safe
    {
        auto factory = new WrapDependencyFactory!(MF)();
        registerMiddleware!MF(name, factory);
    }

    /**
     * Регистрация middleware с использованием существующей фабрики
     */
    void registerMiddleware(MF : WebMiddlewareFactory)(string name, 
            WebMiddlewareFactory factory) @safe
    {
        string uName = name.toUpper;
        _middlewares[uName] = factory;
    }

    /**
     * Регистрация контроллера
     */
    void registerController(C : WebController)(string name) @safe
    {
        alias CF = ComponentFactoryCtor!(WebController, C, UniConf);
        registerController!(CF)(name);
    }

    /**
     * Регистрация контроллера с использованием фабрики
     */
    void registerController(CF : WebControllerFactory)(string name) @safe
    {
        auto factory = new WrapDependencyFactory!(CF)();
        registerController!CF(name, factory);
    }

    /**
     * Регистрация контроллера с использованием существующей фабрики
     */
    void registerController(CF : WebControllerFactory)(string name,
            WebControllerFactory factory) @safe
    {
        string uName = name.toUpper;
        _controllers[uName] = factory;
    }


private:


    WebApplicationServer createServer(UniConf config) @safe
    {
        string webName = config.getOrElse!string("__name", "Undefined");
        logInfo("Configuring web server '%s'", webName);

        URLRouter routes = new URLRouter();
        auto settings = loadHTTPServerSettings(config);

        MiddlewareInfo[] middlewares;

        foreach (UniConf mdwConf; config.toSequence("middleware"))
        {
            string mdwName = mdwConf.getNameOrEnforce(
                        "Not defined middleware name");

            long ordering = mdwConf.getOrElse!long("order", 0);
            string label = mdwConf.getOrElse!string("label", mdwName);
            enforceConfig(!middlewares.canFind!((m) {
                        return m.label == label;
                    }), fmt!"Middleware '%s' already defined"(label));

            auto mdwFactory = mdwName.toUpper in _middlewares;
            enforceConfig(mdwFactory !is null,
                    fmt!"Middleware '%s' not register"(mdwName));

            middlewares ~= MiddlewareInfo(label, ordering, mdwConf, *mdwFactory);
        }

        foreach (UniConf ctrConf; config.toSequence("controller")
                    .filter!((c) => c.getOrElse("enabled", false)))
        {
            string ctrName = getNameOrEnforce(ctrConf,
                        "Not defined controller name");

            auto ctrlFactory = ctrName.toUpper in _controllers;
            enforceConfig(ctrlFactory !is null,
                    fmt!"Controller '%s' not register"(ctrName));

            auto ctrl = ctrlFactory.createComponent(_container, ctrConf);

            auto ctrlMiddlewares = ctrConf.toSequence("middlewares")
                    .map!(pm => pm.get!string);

            // проверка на наличие конфигураций
            foreach (string mdwLabel; ctrlMiddlewares)
                enforceConfig(middlewares.canFind!((m) => m.label == mdwLabel),
                        fmt!"Middleware %s not found configuration"(mdwLabel));

            auto activeMiddlewares = middlewares.filter!((mdwConf) {
                        bool def = mdwConf.config.getOrElse!bool("default", false);
                        return def || ctrlMiddlewares.canFind(mdwConf.label);
                    }).array;

            activeMiddlewares.sort!((a, b) => a.ordering > b.ordering);

            logInfo("Register controller: '%s'", ctrName);
            logInfo("  Activated middlewares: %s", activeMiddlewares
                    .map!(m => m.label));

            string prefix = ctrConf.getOrElse("prefix", "");

            ctrl.registerChains((HTTPMethod method, string path, Chain ch) @safe {
                    string absPath = joinInetPath(prefix, path);
                    foreach (mdwInfo; activeMiddlewares)
                    {
                        WebMiddleware mdw = mdwInfo.factory.createComponent(
                                _container, mdwInfo.config);
                        ch.attachMiddleware(mdw);
                        mdw.registerHandlers(method, absPath, (mm, mp, mh) @safe {
                                routes.match(mm, mp, mh);
                            });
                    }
                    logInfo("  %s: %s", method, absPath);
                    routes.match(method, absPath, ch);
                });
        }

        routes.rebuild();

        return new HTTPApplicationServer(settings, routes);
    }


    struct MiddlewareInfo
    {
        string label;
        long ordering;
        UniConf config;
        WebMiddlewareFactory factory;
    }
}

