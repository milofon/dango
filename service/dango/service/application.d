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
    import dango.system.component : resolveFactory;

    import dango.service.serialization;
    import dango.service.protocol;
    import dango.service.transport;
}


/**
 * Приложение позволяет использовать с сервисами
 */
abstract class ServiceApplication : DaemonApplication
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


    override final void initDependencies(ApplicationContainer container, Properties config)
    {
        container.registerContext!SerializerContext;
        container.registerContext!ProtocolContext;
        container.registerContext!TransportContext;

        initServiceDependencies(container, config);
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
                auto tr = createServiceTransport(servConf);
                tr.listen();
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
    void initServiceDependencies(ApplicationContainer container, Properties config);


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


    ServerTransport createServiceTransport(Properties servConf)
    {
        string serviceName = servConf.getOrElse!string("name", "Undefined");
        logInfo("Configuring service '%s'", serviceName);

        Properties serConf = servConf.getOrEnforce!Properties("serializer",
                "Not defined serializer config for service '" ~ serviceName ~ "'");
        Properties protoConf = servConf.getOrEnforce!Properties("protocol",
                "Not defined protocol config for service '" ~ serviceName ~ "'");
        Properties trConf = servConf.getOrEnforce!Properties("transport",
                "Not defined transport config for service '" ~ serviceName ~ "'");

        string serializerName = getNameOrEnforce(serConf,
                "Not defined serializer name for service '" ~ serviceName ~ "'");
        string protoName = getNameOrEnforce(protoConf,
                "Not defined protocol name for service '" ~ serviceName ~ "'");
        string transportName = getNameOrEnforce(trConf,
                "Not defined transport name for service '" ~ serviceName ~ "'");

        // Т.к. протокол может быть только один, то конфиги сериализатора
        // вынес на верхний уровень
        auto serFactory = container.resolveFactory!Serializer(serializerName);
        configEnforce(serFactory !is null,
                fmt!"Serializer '%s' not register"(serializerName));
        Serializer serializer = serFactory.create(serConf);
        logInfo("Use serializer %s", serializerName);

        auto protoFactory = container.resolveFactory!(ServerProtocol,
                Serializer)(protoName);
        configEnforce(protoFactory !is null,
                fmt!"Protocol '%s' not register"(protoName));
        ServerProtocol protocol = protoFactory.create(serializer, protoConf);
        logInfo("Use protocol %s", protoName);

        auto trFactory = container.resolveFactory!(ServerTransport,
                ServerProtocol)(transportName);
        configEnforce(trFactory !is null,
                fmt!"Transport '%s' not register"(transportName));
        ServerTransport transport = trFactory.create(protocol, trConf);
        logInfo("Use transport %s", transportName);

        return transport;
    }
}

