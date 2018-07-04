/**
 * Модуль транспортного уровня на основе ZeroMQ
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport.zeromq;

private
{
    import core.time : msecs;

    import vibe.core.log;
    import vibe.core.core : yield, Task, runWorkerTaskH, runTask;

    import deimos.zmq.zmq;
    import zmqd;

    import dango.system.component;
    import dango.system.properties : getNameOrEnforce, configEnforce, getOrEnforce;

    import dango.service.types;
    import dango.service.transport.core;
}


/**
 * Объект настроек ZeroMQ
 */
struct ZeroMQTransportSettings
{
    string uri;
    bool useBroker;
}


/**
 * Транспорт использующий функционал ZeroMQ
 */
class ZeroMQServerTransport : BaseServerTransport!"ZEROMQ"
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
        ubyte[0] empty;
        ubyte[] buffer;

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
class ZeroMQServerTransportFactory : BaseServerTransportFactory!ZeroMQServerTransport
{
    this(ApplicationContainer container)
    {
        super(container);
    }


    override ZeroMQServerTransport create(ServerProtocol protocol, Properties config)
    {
        auto ret = new ZeroMQServerTransport(protocol, loadServiceSettings(config));
        container.autowire(ret);
        return ret;
    }
}


private:


ZeroMQTransportSettings loadServiceSettings(Properties config)
{
    auto uri = config.getOrEnforce!string("bind",
                "ZeroMQ transport is not defined bind");
    auto useBroker = config.getOrElse!bool("broker", false);
    return ZeroMQTransportSettings(uri, useBroker);
}

