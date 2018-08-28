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

    import dango.system.properties : getOrEnforce, getNameOrEnforce;
    import dango.system.exception : configEnforce;
    import dango.system.container : resolveFactory;

    import dango.service.serialization;
    import dango.service.protocol;
    import dango.service.transport;
}


/**
 * Приложение позволяет использовать с сервисами
 */
abstract class BaseServiceApplication : BaseDaemonApplication
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

    override void doInitializeDependencies(Properties config)
    {
        super.doInitializeDependencies(config);
        container.registerContext!SerializerContext;
        container.registerContext!ProtocolContext;
        container.registerContext!TransportContext;
    }


    final override void initializeDaemon(Properties config)
    {
        initializeServiceApplication(config);

        auto sConfgs = config.getOrEnforce!Properties("service",
                "Not found service configurations");

        foreach (Properties servConf; sConfgs.getArray())
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
     * Инициализация сервиса
     * Params:
     * config = Общая конфигурация приложения
     */
    void initializeServiceApplication(Properties config){}

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


    void createServiceTransports(ApplicationContainer container, Properties servConf,
            void delegate(ServerTransport tr) cb)
    {
        string serviceName = servConf.getOrElse!string("name", "Undefined");
        logInfo("Configuring service '%s'", serviceName);

        Properties serConf = servConf.getOrEnforce!Properties("serializer",
                "Not defined serializer config for service '" ~ serviceName ~ "'");
        Properties protoConf = servConf.getOrEnforce!Properties("protocol",
                "Not defined protocol config for service '" ~ serviceName ~ "'");

        string serializerName = getNameOrEnforce(serConf,
                "Not defined serializer name for service '" ~ serviceName ~ "'");
        string protoName = getNameOrEnforce(protoConf,
                "Not defined protocol name for service '" ~ serviceName ~ "'");

        // Т.к. протокол может быть только один, то конфиги сериализатора
        // вынес на верхний уровень
        auto serFactory = container.resolveFactory!(Serializer, Properties)(serializerName);
        configEnforce(serFactory !is null,
                fmt!"Serializer '%s' not register"(serializerName));
        logInfo("Use serializer '%s'", serializerName);
        Serializer serializer = serFactory.create(serConf);

        auto protoFactory = container.resolveFactory!(ServerProtocol, Properties,
                ApplicationContainer, Serializer)(protoName);
        configEnforce(protoFactory !is null,
                fmt!"Protocol '%s' not register"(protoName));
        logInfo("Use protocol '%s'", protoName);
        ServerProtocol protocol = protoFactory.create(protoConf, container, serializer);

        foreach (Properties trConf; servConf.getArray("transport"))
        {
            string transportName = getNameOrEnforce(trConf,
                    "Not defined transport name for service '" ~ serviceName ~ "'");

            auto trFactory = container.resolveFactory!(ServerTransport, Properties,
                    ApplicationContainer, ServerProtocol)(transportName);
            configEnforce(trFactory !is null,
                    fmt!"Transport '%s' not register"(transportName));
            logInfo("Use transport '%s'", transportName);

            ServerTransport transport = trFactory.create(trConf, container, protocol);
            cb(transport);
        }
    }
}

