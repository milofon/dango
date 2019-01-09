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
    import dango.system.application;
}

private
{
    import std.algorithm.iteration : map;
    import std.format : fmt = format;

    import uniconf.core.exception : enforceConfig;

    import dango.system.properties : getNameOrEnforce;
    import dango.system.inject : registerContext, resolveNamedFactory,
            ResolveOption;

    import dango.service.protocol.core : ServerProtocolContainer;
    import dango.service.serialization;
    import dango.service.protocol;
    import dango.service.transport;
}


/**
 * Приложение сервис
 */
interface ServiceApplication
{
    /**
     * Инициализация сервиса
     * Params:
     * config = Общая конфигурация приложения
     */
    void initializeServiceApplication(Config config);

    /**
     * Завершение работы сервиса
     * Params:
     * exitCode = Код возврата
     */
    int finalizeServiceApplication(int exitCode);
}


/**
 * Приложение позволяет использовать с сервисами
 */
abstract class BaseServiceApplication : BaseDaemonApplication, ServiceApplication
{
    private ServerTransport[] _transports;


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
        container.register!ServerProtocolContainer;
        container.registerContext!SerializerContext;
        container.registerContext!ProtocolContext;
        container.registerContext!TransportContext;
    }


    final void initializeDaemon(Config config)
    {
        initializeServiceApplication(config);

        auto servConfigs = config.getOrEnforce!Config("service",
                "Not found service configurations");

        foreach (Config servConf; servConfigs.getArray())
        {
            if (servConf.getOrElse("enabled", false))
            {
                createServiceTransports(container, servConf, (tr) {
                    tr.listen();
                    _transports ~= tr;
                });
            }
        }
    }


    final override int finalizeDaemon(int exitCode)
    {
        foreach (ServerTransport tr; _transports)
            tr.shutdown();
        return finalizeServiceApplication(exitCode);
    }

    /**
     * Завершение работы сервиса
     * Params:
     * exitCode = Код возврата
     */
    int finalizeServiceApplication(int exitCode)
    {
        return exitCode;
    }


private:


    void createServiceTransports(ApplicationContainer container, Config servConf,
            void delegate(ServerTransport tr) cb)
    {
        string serviceName = servConf.getOrElse!string("name", "Undefined");
        logInfo("Configuring service '%s'", serviceName);

        auto protoConfs = servConf.getArray("protocol");
        enforceConfig(protoConfs.length > 0,
                "Not defined protocols config for service '" ~ serviceName ~ "'");

        auto protoContainer = container.resolve!ServerProtocolContainer;
        foreach (Config protoConf; protoConfs)
        {
            string protoName = protoConf.getNameOrEnforce(
                    "Not defined protocol name for service '" ~ serviceName ~ "'");
            string protoType = protoConf.getOrEnforce!string("type",
                    "Not defined protocol type for protocol '" ~ protoName ~ "'");

            auto protoFactory = container.resolveNamedFactory!ServerProtocol(protoType,
                    ResolveOption.noResolveException);
            enforceConfig(protoFactory !is null,
                    fmt!"Protocol '%s' not register"(protoType));

            logInfo("Register protocol %s(%s)", protoName, protoType);

            protoContainer.registerProtocolFactory(protoName, protoFactory,
                    protoConf, container);
        }


        foreach (Config trConf; servConf.getArray("transport"))
        {
            string transportName = getNameOrEnforce(trConf,
                    "Not defined transport name for service '" ~ serviceName ~ "'");

            auto trFactory = container.resolveNamedFactory!ServerTransport(
                    transportName, ResolveOption.noResolveException);

            enforceConfig(trFactory !is null,
                    fmt!"Transport '%s' not register"(transportName));

            logInfo("Use transport '%s'", transportName);

            ServerTransport transport = trFactory.createInstance(trConf, container);
            cb(transport);
        }
    }
}

