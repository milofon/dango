/**
 * Модуль транспортного уровня на основе ZeroMQ
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport.zeromq.server;

private
{
    import core.time : msecs, Duration;
    import std.format : fmt = format;

    import vibe.core.log;
    import vibe.core.core : yield, Task, runWorkerTaskH, runTask;

    import uniconf.core : Config;
    import uniconf.core.exception : enforceConfig;

    import deimos.zmq.zmq;
    import zmqd;

    import dango.system.container;

    import dango.service.transport.core;
    import dango.service.protocol : ServerProtocol;
    import dango.service.protocol.core : ServerProtocolContainer;
}


/**
 * Транспорт использующий функционал ZeroMQ
 */
class ZeroMQServerTransport : ServerTransport
{
    private
    {
        ServerProtocol _protocol;
        ZeroMQTransportSettings _settings;

        Task _task;
        bool _running;
        Bytes delegate(Bytes) _hdl;
    }


    this(ServerProtocol protocol, ZeroMQTransportSettings settings)
    {
        this._protocol = protocol;
        this._settings = settings;
    }


    void listen()
    {
        const ver = zmqVersion();
        logInfo("Version ZeroMQ: %s.%s.%s", ver.major, ver.minor, ver.patch);

        _hdl = &_protocol.handle;
        _task = runWorkerTaskH!(ZeroMQServerTransport.process)(cast(shared)this);
        logInfo("Transport ZeroMQ Start");
    }


    void shutdown()
    {
        _running = false;
        logInfo("Transport ZeroMQ Stop");
    }


    void process() shared
    {
        _running = true;
        ubyte[] buffer;
        ubyte[0] empty;

        auto worker = Socket(SocketType.router);
        worker.bind(_settings.uri);
        logInfo("Listening for requests on %s", _settings.uri);

        PollItem[] items = [
            PollItem(worker, PollFlags.pollIn),
        ];

        scope(exit)
            worker.close();

        while (_running)
        {
            poll(items, 100.msecs);
            if (items[0].returnedEvents & PollFlags.pollIn)
            {
                auto payload = Frame();
                bool needSplit = false;
                Bytes identity;
                buffer.length = 0;

                worker.receive(payload);
                identity = payload.data.idup;

                while (payload.more)
                {
                    worker.receive(payload);
                    if (payload.more && payload.size == 0)
                        needSplit = true;
                    else
                        buffer ~= payload.data.idup;
                }

                runTask((Bytes identity, Bytes data, bool needSplit) {
                        auto res = _hdl(data);
                        worker.send(identity, true);
                        if (needSplit)
                            worker.send(empty, true);
                        worker.send(res, false);
                    }, identity, buffer.idup, needSplit);
            }
            yield();
        }
    }
}


/**
 * Фабрика транспорта использующий функционал ZeroMQ
 */
class ZeroMQServerTransportFactory : ServerTransportFactory
{
    @Autowire
    ServerProtocolContainer protoContainer;


    ServerTransport createComponent(Config config, ApplicationContainer container)
    {
        string protoName = config.getOrEnforce!string("protocol",
                "Not defined protocol type for zeromq transport");
        auto protocol = protoContainer.createProtocol(protoName);
        enforceConfig(protocol, fmt!"Protocol %s not registered"(protoName));
        return new ZeroMQServerTransport(protocol, loadServiceSettings(config));
    }
}


private:


/**
 * Объект настроек ZeroMQ
 */
struct ZeroMQTransportSettings
{
    string uri;
    bool useBroker;
}


/**
 * Парсит конфигурацию ZeroMQ
 *
 * Params:
 * config = Объект конфигурации
 */
ZeroMQTransportSettings loadServiceSettings(Config config)
{
    auto uri = config.getOrEnforce!string("bind",
            "ZeroMQ transport is not defined bind");
    auto useBroker = config.getOrElse!bool("broker", false);
    return ZeroMQTransportSettings(uri, useBroker);
}

