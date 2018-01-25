/**
 * Реализация приложения для содания приложения сервиса
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.application;

public
{
    import proped : Properties;
    import poodinis : DependencyContainer;
}

private
{
    import std.format : fmt = format;

    import dango.system.application;
    import dango.system.container : resolveByName;

    import dango.service.exception;
    import dango.service.dispatcher;
    import dango.service.transport;
    import dango.service.controller;
}


abstract class ServiceApplication : DaemonApplication
{
    private Transport[] _transports;


    this(string name, string release)
    {
        super(name, release);
    }


    override final void initDependencies(shared(DependencyContainer) container, Properties config)
    {
        container.registerContext!DispatcherContext;
        container.registerContext!TransportContext;

        initServiceDependencies(container, config);
    }


    this(string name, SemVer release)
    {
        super(name, release);
    }


    override void initializeDaemon(Properties config)
    {
        initializeService(config);

        auto sConfgs = config.getOrEnforce!Properties("service",
                "Not found service configurations");

        foreach (Properties servConf; sConfgs.getArray())
        {
            if (servConf.getOrElse("enabled", false))
            {
                Properties trConf = servConf.getOrEnforce!Properties("transport",
                        "Not defined transport config");

                string servName = servConf.getOrEnforce!string("name",
                        "Not defined service name");
                string serialiserName = servConf.getOrEnforce!string("serializer",
                        "Not defined serialiser type");
                string transportName = trConf.getOrEnforce!string("name",
                        "Not defined transport name");

                Transport tr = container.resolveByName!Transport(transportName);
                configEnforce(tr !is null,
                        "Transport '%s' not register".fmt(transportName));

                Dispatcher dsp = container.resolveByName!Dispatcher(serialiserName);
                configEnforce(dsp !is null,
                        "Dispatcher '%s' not register".fmt(serialiserName));

                foreach (Properties ctrConf; servConf.getArray("controller"))
                {
                    auto ctrName = ctrConf.isObject ? ctrConf.get!string("name") : ctrConf.get!string;
                    if (ctrName.isNull)
                        continue;

                    Controller ctrl = container.resolveByName!Controller(ctrName.get);
                    configEnforce(ctrl !is null, "Controller '%s' not register".fmt(ctrName));

                    ctrl.initialize(ctrConf);
                    if (ctrl.enabled)
                    {
                        ctrl.register(dsp);
                        logInfo("Register '%s' controller", ctrName);
                    }
                }

                tr.listen(dsp, trConf);
                _transports ~= tr;
            }
        }
    }


    override int finalizeDaemon(int exitCode)
    {
        foreach (Transport tr; _transports)
            tr.shutdown();
        return finalizeService(exitCode);
    }

protected:

    /**
     * Регистрация зависимостей сервиса
     * Params:
     * container = DI контейнер
     * config = Общая конфигурация приложения
     */
    void initServiceDependencies(shared(DependencyContainer) container, Properties config);


    /**
     * Инициализация сервиса
     * Params:
     * config = Общая конфигурация приложения
     */
    void initializeService(Properties config);


    /**
     * Завершение работы сервиса
     * Params:
     * exitCode = Код возврата
     */
    int finalizeService(int exitCode);
}
