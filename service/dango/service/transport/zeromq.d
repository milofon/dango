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
    import core.time : msecs, Duration;
    import core.memory : GC;

    import std.datetime : Clock;

    import vibe.core.log;
    import vibe.core.core : yield, Task, runWorkerTaskH, runTask;
    import vibe.core.connectionpool : ConnectionPool;

    import proped : Properties;
    import deimos.zmq.zmq;
    import zmqd;

    import dango.system.container;
    import dango.system.properties : getNameOrEnforce, configEnforce, getOrEnforce;

    import dango.service.types;
    import dango.service.exception;
    import dango.service.transport.core;
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
class ZeroMQServerTransportFactory : BaseServerTransportFactory
{
    ServerTransport createComponent(Properties config, ApplicationContainer container,
            ServerProtocol protocol)
    {
        auto ret = new ZeroMQServerTransport(protocol, loadServiceSettings(config));
        return ret;
    }
}


/**
 * Транспорт использующий функционал ZeroMQ
 */
class ZeroMQClientTransport : ClientTransport
{
    private
    {
        ConnectionPool!ZeroMQConnection _pool;
    }


    this(string uri, long timeout)
    {
        _pool = new ConnectionPool!ZeroMQConnection({
                auto ret = new ZeroMQConnection(uri, timeout.msecs);
                ret.connect();
                return ret;
            });
    }


    Future!Bytes request(Bytes bytes)
    {
        return _pool.lockConnection().request(bytes);
    }
}


/**
 * Фабрика клиенсткого транспорта использующего функционал ZeroMQ
 */
class ZeroMQClientTransportFactory : BaseClientTransportFactory
{
    ClientTransport createComponent(Properties config)
    {
        string uri = config.getOrEnforce!string("uri",
                "Not defined uri for client transport");
        long timeout = config.getOrElse!long("timeout", 500);
        return new ZeroMQClientTransport(uri, timeout);
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


class ZeroMQConnection
{
    private
    {
        Socket _socket;
        PollItem[] _items;
        bool _connected;
        Duration _timeout;
        string _uri;
    }


    this(string uri, Duration timeout)
    {
        this._uri = uri;
        this._timeout = timeout;
    }


    bool connected() @property
    {
        return _socket.initialized && _connected;
    }


    void connect()
    {
        _socket = Socket(SocketType.req);
        _items = [PollItem(_socket, PollFlags.pollIn)];
        _socket.connect(_uri);
        _connected = true;
    }


    void disconnect()
    {
        _socket.linger = Duration.zero;
        _socket.close();
        _connected = false;
    }


    Future!Bytes request(Bytes bytes)
    {
        // TODO: потокобезопосность
        import vibe.core.concurrency;

        GC.disable();
        scope(exit) GC.enable();

        _socket.send(bytes);

        return async({
            auto start = Clock.currTime;
            auto current = start;
            auto payload = Frame();
            ubyte[] buffer;

            GC.disable();
            scope(exit) GC.enable();

            while ((current - start) < _timeout)
            {
                poll(_items, 100.msecs);
                if (_items[0].returnedEvents & PollFlags.pollIn)
                {
                    _socket.receive(payload);

                    buffer.length = 0;
                    buffer ~= payload.data;

                    while (payload.more)
                    {
                        _socket.receive(payload);
                        buffer ~= payload.data;
                    }

                    return buffer.idup;
                }

                current = Clock.currTime;
                yield();
            }

            disconnect();
            throw new TransportException("Request timeout error");
        });
    }
}



ZeroMQTransportSettings loadServiceSettings(Properties config)
{
    auto uri = config.getOrEnforce!string("bind",
                "ZeroMQ transport is not defined bind");
    auto useBroker = config.getOrElse!bool("broker", false);
    return ZeroMQTransportSettings(uri, useBroker);
}

