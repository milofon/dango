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
    import dango.service.transport;
    import dango.service.serializer;
    import dango.service.protocol;
    import dango.service.dispatcher;
    import dango.service.controller;
}


abstract class ServiceApplication : DaemonApplication
{
    private ServerTransport[] _transports;


    this(string name, string release)
    {
        super(name, release);
    }


    override final void initDependencies(shared(DependencyContainer) container, Properties config)
    {
        container.registerContext!TransportContext;
        container.registerContext!SerializerContext;
        container.registerContext!ProtocolContext;

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
                Properties serConf = servConf.getOrEnforce!Properties("serializer",
                        "Not defined serializer config");
                Properties protoConf = servConf.getOrEnforce!Properties("protocol",
                        "Not defined protocol config");

                string serviceName = servConf.getOrEnforce!string("name",
                        "Not defined service name");
                string serializerName = getNameOrEnforce(serConf,
                        "Not defined serializer name");
                string protoName = getNameOrEnforce(protoConf,
                        "Not defined protocol name");
                string transportName = getNameOrEnforce(trConf,
                        "Not defined transport name");

                Serializer serializer = container.resolveByName!Serializer(serializerName);
                serializer.initialize(serConf);
                configEnforce(serializer !is null,
                        "Serializer '%s' not register".fmt(serializerName));

                Dispatcher dispatcher = new Dispatcher();

                RpcServerProtocol protocol = container.resolveByName!RpcServerProtocol(protoName);
                configEnforce(protocol !is null,
                        "Protocol '%s' not register".fmt(protoName));
                protocol.initialize(dispatcher, serializer, protoConf);

                ServerTransport tr = container.resolveByName!ServerTransport(transportName);
                configEnforce(tr !is null,
                        "Transport '%s' not register".fmt(transportName));

                foreach (Properties ctrConf; servConf.getArray("controller"))
                {
                    string ctrName = getNameOrEnforce(ctrConf,
                        "Not defined controller name");

                    Controller ctrl = container.resolveByName!Controller(ctrName);
                    configEnforce(ctrl !is null, "Controller '%s' not register".fmt(ctrName));

                    ctrl.initialize(serializer, ctrConf);
                    if (ctrl.enabled)
                    {
                        ctrl.register(dispatcher);
                        logInfo("Register '%s' controller", ctrName);
                    }
                }

                tr.listen(protocol, trConf);
                _transports ~= tr;
            }
        }
    }


    override int finalizeDaemon(int exitCode)
    {
        foreach (ServerTransport tr; _transports)
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

private:

    string getNameOrEnforce(Properties config, string msg)
    {
        if (config.isObject)
            return config.getOrEnforce!string("name", msg);
        else
        {
            auto val = config.get!string;
            configEnforce(!val.isNull, msg);
            return val.get;
        }
    }
}
