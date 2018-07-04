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
    import dango.system.component : resolveFactory, registerFactory;
    import dango.system.properties : getOrEnforce;

    import dango.web.server;
    import dango.web.middlewares;
    import dango.web.controllers;
}


/**
 * Приложение позволяет инициализировать веб приложение
 */
abstract class WebApplication : DaemonApplication
{
    private
    {
        WebApplicationServer _server;
    }


    this(string name, string release)
    {
        super(name, release);
    }


    this(string name, SemVer release)
    {
        super(name, release);
    }


    override final void initDependencies(ApplicationContainer container, Properties config)
    {
        container.registerFactory!(WebApplicationServer, WebApplicationServerFactory);
        container.registerContext!WebMiddlewaresContext;
        container.registerContext!WebControllersContext;
        initWebDependencies(container, config);
    }


    override void initializeDaemon(Properties config)
    {
        initializeWeb(config);

        auto webConf = config.getOrEnforce!Properties("web",
                "Not found web application configurations");

        auto serverFactory = container.resolveFactory!WebApplicationServer;
        _server = serverFactory.create(webConf);
        _server.listen();
    }


    override int finalizeDaemon(int exitCode)
    {
        _server.shutdown();
        return finalizeWeb(exitCode);
    }


protected:


    /**
     * Регистрация зависимостей сервиса
     * Params:
     * container = DI контейнер
     * config = Общая конфигурация приложения
     */
    void initWebDependencies(ApplicationContainer container, Properties config);

    /**
     * Инициализация сервиса
     * Params:
     * config = Общая конфигурация приложения
     */
    void initializeWeb(Properties config);

    /**
     * Завершение работы сервиса
     * Params:
     * exitCode = Код возврата
     */
    int finalizeWeb(int exitCode);
}

