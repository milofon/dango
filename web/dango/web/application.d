/**
 * Реализация приложения для содания веб приложения
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-26
 */

module dango.web.application;

public
{
    import dango.system.application;
}

private
{
    import dango.system.container : registerFactory, resolveFactory;

    import dango.web.server;
    import dango.web.middlewares;
    import dango.web.controllers;
}


/**
 * Базовая реализация приложения позволяет инициализировать веб приложение
 */
abstract class BaseWebApplication : BaseDaemonApplication
{
    private
    {
        WebApplicationServer[] _servers;
    }


    this(string name, string release)
    {
        super(name, release);
    }


    this(string name, SemVer release)
    {
        super(name, release);
    }

protected:

    override void doInitializeDependencies(Config config)
    {
        super.doInitializeDependencies(config);
        doRegisterServerDependencies(config);
        container.registerContext!WebMiddlewaresContext;
        container.registerContext!WebControllersContext;
    }

    /**
     * Регистрация сервера
     */
    void doRegisterServerDependencies(Config config)
    {
        container.registerFactory!(RouterWebApplicationServerFactory,
                RouterWebApplicationServer);
    }

    /**
     * Инициализация сервиса
     * Params:
     * config = Общая конфигурация приложения
     */
    void initializeWebApplication(Config config) {}

    /**
     * Завершение работы сервиса
     * Params:
     * exitCode = Код возврата
     */
    int finalizeWebApplication(int exitCode)
    {
        return exitCode;
    }


    final override void initializeDaemon(Config config)
    {
        initializeWebApplication(config);

        auto webConfigs = config.getOrEnforce!Config("web",
                "Not found web application configurations");

        foreach (Config webConf; webConfigs.getArray())
        {
            if (webConf.getOrElse("enabled", false))
            {
                auto serverFactory = container.resolveFactory!(WebApplicationServer,
                        Config, ApplicationContainer);
                auto server = serverFactory.create(webConf, container);
                server.listen();
                _servers ~= server;
            }
        }
    }


    final override int finalizeDaemon(int exitCode)
    {
        foreach (WebApplicationServer server; _servers)
            server.shutdown();
        return finalizeWebApplication(exitCode);
    }
}

