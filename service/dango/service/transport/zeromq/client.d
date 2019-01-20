/**
 * Модуль транспорта клиента ZeroMQ
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-12-13
 */

module dango.service.transport.zeromq.client;

private
{
    import core.time : msecs, Duration;
    import core.memory : GC;
    import std.datetime : Clock;

    import vibe.core.core : yield, Task, runWorkerTaskH, runTask;
    import vibe.core.connectionpool : ConnectionPool;
    import uniconf.core : Config;

    import deimos.zmq.zmq;
    import zmqd;

    import dango.system.exception;
    import dango.service.transport.core;
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
        _pool = new ConnectionPool!ZeroMQConnection(() @trusted {
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
class ZeroMQClientTransportFactory : ClientTransportFactory
{
    ClientTransport createComponent(Config config)
    {
        string uri = config.getOrEnforce!string("uri",
                "Not defined uri for client transport");
        long timeout = config.getOrElse!long("timeout", 500);
        return new ZeroMQClientTransport(uri, timeout);
    }
}


/**
 * Соединение по протоколу ZeroMQ
 */
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
        this._timeout = timeout;
        this._uri = uri;
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
            throw new ZeroMQTransportException("Request timeout error");
        });
    }
}


/**
 * Исключение транспорта
 */
class ZeroMQTransportException : Exception
{
    mixin ExceptionMixin!();
}

