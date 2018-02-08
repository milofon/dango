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
    import std.string : toStringz, fromStringz;

    import vibe.core.log;

    import deimos.zmq.zmq;
    import zmqd;

    import dango.service.exception;
    import dango.service.transport.core;
}


alias Handler = ubyte[] delegate(ubyte[]);


struct ZeroMQTransportSettings
{
    string uri;
    bool useBroker;
}



class ZeroMQTransport : Transport
{
    private
    {
        ZeroMQTransportSettings _settings;
        ZeroMQWorker _worker;
    }


    void listen(RpcProtocol protocol, Properties config)
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
