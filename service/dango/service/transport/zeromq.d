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
    import core.thread;

    import std.datetime : Clock;
    import std.string : toStringz, fromStringz;

    import vibe.core.log;
    import vibe.core.core : yield;

    import deimos.zmq.zmq;
    import zmqd;

    import dango.service.exception;
    import dango.system.properties : getOrEnforce;

    import dango.service.transport.core;
}


alias Handler = ubyte[] delegate(ubyte[]);


struct ZeroMQTransportSettings
{
    string uri;
    bool useBroker;
}



class ZeroMQServerTransport : ServerTransport
{
    private
    {
        ZeroMQTransportSettings _settings;
        ZeroMQWorker _worker;
    }


    void listen(RpcServerProtocol protocol, Properties config)
    {
        _settings.uri = config.getOrEnforce!string("bind",
                "ZeroMQ transport is not defined bind");
        _settings.useBroker = config.getOrElse!bool("broker", false);

        const ver = zmqVersion();
        logInfo("Version ZeroMQ: %s.%s.%s", ver.major, ver.minor, ver.patch);


        ubyte[] handler(ubyte[] data)
        {
            return protocol.handle(data);
        }

        _worker = new ZeroMQWorker(_settings, &handler);
        _worker.start();

        logInfo("Transport ZeroMQ Start");
    }


    void shutdown()
    {
        _worker.stop();
        logInfo("Transport ZeroMQ Stop");
    }
}



private final class ZeroMQWorker : Thread
{
    private
    {
        ZeroMQTransportSettings _settings;
        bool _running;
        Handler _handler;
    }


    this(ZeroMQTransportSettings settings, Handler handler)
    {
        _settings = settings;
        _handler = handler;
        super(&run);
    }


    void run()
    {
        _running = true;
        ubyte[] buffer;

        auto worker = Socket(SocketType.rep);

        if (_settings.useBroker)
        {
            worker.connect(_settings.uri);
            logInfo("Connect to broker %s", _settings.uri);
        }
        else
        {
            worker.bind(_settings.uri);
            logInfo("Listening for requests on %s", _settings.uri);
        }


        PollItem[] items = [
            PollItem(worker, PollFlags.pollIn),
        ];

        auto payload = Frame();

        while (_running)
        {
            poll(items, 100.msecs);
            if (items[0].returnedEvents & PollFlags.pollIn)
            {
                worker.receive(payload);

                buffer.length = 0;
                buffer ~= payload.data;

                while (payload.more)
                {
                    worker.receive(payload);
                    buffer ~= payload.data;
                }
                ubyte[] resData = _handler(buffer);
                worker.send(resData);
            }
        }
    }


    void stop()
    {
        _running = false;
    }
}



class ZeroMQClientConnection : ClientConnection
{
    private
    {
        Socket _socket;
        PollItem[] _items;
        string _uri;
        ubyte[] _buffer;
        bool _connected;
        Duration _timeout;
    }


    this(string uri, uint timeout)
    {
        _timeout = timeout.msecs;
        _uri = uri;
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


    ubyte[] request(ubyte[] bytes)
    {
        _socket.send(bytes);

        auto payload = Frame();
        auto start = Clock.currTime;
        auto current = start;

        while ((current - start) < _timeout)
        {
            poll(_items, 100.msecs);
            if (_items[0].returnedEvents & PollFlags.pollIn)
            {
                _socket.receive(payload);

                _buffer.length = 0;
                _buffer ~= payload.data;

                while (payload.more)
                {
                    _socket.receive(payload);
                    _buffer ~= payload.data;
                }
                return _buffer.dup;
            }
            current = Clock.currTime;
            yield();
        }

        disconnect();
        throw new TransportException("Request timeout error");
    }
}



class ZeroMQClientConnectionPool : WaitClientConnectionPool!ZeroMQClientConnection
{
    private
    {
        string _uri;
        uint _timeout;
    }


    this(string uri, uint timeout, uint size)
    {
        _uri = uri;
        _timeout = timeout;
        super(size);
    }


    ZeroMQClientConnection createNewConnection()
    {
        return new ZeroMQClientConnection(_uri, _timeout);
    }
}



class ZeroMQClientTransport : ClientTransport
{
    private
    {
        ZeroMQClientConnectionPool _pool;
    }


    this() {}


    this(string uri, uint timeout, uint size)
    {
        _pool = new ZeroMQClientConnectionPool(uri, timeout, size);
    }


    void initialize(Properties config)
    {
        string uri = config.getOrEnforce!string("uri",
                "Not defined uri for client transport");
        long timeout = config.getOrElse!long("timeout", 500);
        long poolSize = config.getOrElse!long("poolSize", 10);
        _pool = new ZeroMQClientConnectionPool(uri, cast(uint)timeout, cast(uint)poolSize);
    }


    ubyte[] request(ubyte[] bytes)
    {
        auto conn = _pool.getConnection();
        scope(exit) _pool.freeConnection(conn);
        return conn.request(bytes);
    }
}
