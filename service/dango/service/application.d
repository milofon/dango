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
    import std.format : fmt = format;

    import uniconf.core.exception : enforceConfig;

    import dango.system.properties : getNameOrEnforce;
    import dango.system.container : resolveFactory;

    import dango.service.serialization;
    import dango.service.protocol;
    import dango.service.transport;
}


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
        container.registerContext!SerializerContext;
        container.registerContext!ProtocolContext;
        container.registerContext!TransportContext;
    }


    final void initializeDaemon(Config config)
    {
        initializeServiceApplication(config);

        auto sConfgs = config.getOrEnforce!Config("service",
                "Not found service configurations");

        foreach (Config servConf; sConfgs.getArray())
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

        Config serConf = servConf.getOrEnforce!Config("serializer",
                "Not defined serializer config for service '" ~ serviceName ~ "'");
        Config protoConf = servConf.getOrEnforce!Config("protocol",
                "Not defined protocol config for service '" ~ serviceName ~ "'");

        string serializerName = getNameOrEnforce(serConf,
                "Not defined serializer name for service '" ~ serviceName ~ "'");
        string protoName = getNameOrEnforce(protoConf,
                "Not defined protocol name for service '" ~ serviceName ~ "'");

        // Т.к. протокол может быть только один, то конфиги сериализатора
        // вынес на верхний уровень
        auto serFactory = container.resolveFactory!(Serializer, Config)(serializerName);
        enforceConfig(serFactory !is null,
                fmt!"Serializer '%s' not register"(serializerName));
        logInfo("Use serializer '%s'", serializerName);
        Serializer serializer = serFactory.create(serConf);

        auto protoFactory = container.resolveFactory!(ServerProtocol, Config,
                ApplicationContainer, Serializer)(protoName);
        enforceConfig(protoFactory !is null,
                fmt!"Protocol '%s' not register"(protoName));
        logInfo("Use protocol '%s'", protoName);
        ServerProtocol protocol = protoFactory.create(protoConf, container, serializer);

        foreach (Config trConf; servConf.getArray("transport"))
        {
            string transportName = getNameOrEnforce(trConf,
                    "Not defined transport name for service '" ~ serviceName ~ "'");

            auto trFactory = container.resolveFactory!(ServerTransport, Config,
                    ApplicationContainer, ServerProtocol)(transportName);
            enforceConfig(trFactory !is null,
                    fmt!"Transport '%s' not register"(transportName));
            logInfo("Use transport '%s'", transportName);

            ServerTransport transport = trFactory.create(trConf, container, protocol);
            cb(transport);
        }
    }
}

