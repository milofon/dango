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

    import dango.service.exception;
    import dango.service.transport.core;
}



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
        Dispatcher _dispatcher;
    }


    void listen(Dispatcher dispatcher, Properties config)
    {
        _dispatcher = dispatcher;

        _settings.uri = config.getOrEnforce!string("bind",
                "ZeroMQ transport is not defined bind");
        _settings.useBroker = config.getOrElse!bool("broker", false);

        int major, minor, patch;
        zmq_version(&major, &minor, &patch);
        logInfo("Version ZeroMQ: %s.%s.%s", major, minor, patch);

        _worker = new ZeroMQWorker(_settings, &mainHandler);
        _worker.start();

        logInfo("Transport ZeroMQ Start");
    }


    void shutdown()
    {
        _worker.stop();
        logInfo("Transport ZeroMQ Stop");
    }

private:

    ubyte[] mainHandler(ubyte[] data) nothrow
    {
        return _dispatcher.handle(data);
    }
}


alias LiberatorResources = void delegate();


private final class ZeroMQWorker : Thread
{
    private
    {
        ZeroMQTransportSettings _settings;
        bool _running;
        LiberatorResources _liberator;
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
        auto ctx = zmq_ctx_new();
        void *socket;
        int rc;

        if (_settings.useBroker)
            socket = zmq_socket(ctx, ZMQ_REQ);
        else
            socket = zmq_socket(ctx, ZMQ_REP);

        transportEnforce(socket !is null, "Error create reply socket");

        _liberator = () {
            zmq_close(socket);
            zmq_ctx_term(ctx);
            zmq_ctx_destroy(ctx);
        };

        scope(exit) _liberator();

        if (_settings.useBroker)
        {
            zmq_connect(socket, _settings.uri.toStringz);
            rc = sendHandshakeBroker(socket);
        }
        else
            rc = zmq_bind(socket, _settings.uri.toStringz);

        if (rc)
        {
            auto error = zmq_strerror(rc);
            throw new TransportException(cast(string)fromStringz(error));
        }
        else
            logInfo("Start requester on : %s", _settings.uri);

        zmq_pollitem_t poll_fd;
        poll_fd.socket = socket;
        poll_fd.events = ZMQ_POLLIN;
        poll_fd.revents = 0;

        while (_running)
        {
            rc = zmq_poll(&poll_fd, 1, 500);
            if (rc < 0)
                break;
            if (rc == 0)
                continue;

            if (poll_fd.revents & ZMQ_POLLIN)
            {
                poll_fd.revents &= ~ZMQ_POLLIN;
                handleMessage(socket, rc);
            }
        }

        logInfo("Worker done...");
    }


    void stop()
    {
        _running = false;
    }

private:

    int sendHandshakeBroker(void* socket)
    {
        ubyte[] great = cast(ubyte[])"NODE_INFO";
        zmq_send(socket, great.ptr, great.length, ZMQ_SNDMORE);

        struct Greater
        {
            bool isBroker;
            int workersCount;
        }

        // Response!Greater res;
        // res.success = true;
        // res.data = Greater(false, 1);
        // Message!K msg = Message!K(0, pack(res));

        // ubyte[] msgData = serializeMessage(msg);
        // int ret = zmq_send(socket, msgData.ptr, msgData.length, 0);

        // return (ret > 0) ? 0 : 1;
        return 0;
    }


    ubyte[] readData(zmq_msg_t* msg) nothrow
    {
        size_t len = zmq_msg_size(msg);
        ubyte[] reqData = new ubyte[](len);
        reqData[0..len] = cast(ubyte[])zmq_msg_data(msg)[0..len];
        return reqData;
    }


    void handleMessage(void* socket, int lenMsg) nothrow
    {
        bool idExists = false;

        zmq_msg_t request;
        int rc = zmq_msg_init(&request);
        assert(rc == 0);
        scope (exit)
            zmq_msg_close(&request);

        rc = zmq_msg_recv(&request, socket, ZMQ_DONTWAIT);
        if (rc < 0)
            return;

        ubyte[] reqData;
        ubyte[] identifier;
        if (zmq_msg_more(&request))
        {
            idExists = true;
            identifier = readData(&request);

            rc = zmq_msg_recv(&request, socket, ZMQ_DONTWAIT);
            if (rc < 0)
                return;

            if (zmq_msg_more(&request))
            {
                rc = zmq_msg_recv(&request, socket, ZMQ_DONTWAIT);
                if (rc < 0)
                    return;
            }
        }

        reqData = readData(&request);
        ubyte[] resData = _handler(reqData);
        size_t len = resData.length;

        if (idExists)
        {
            rc = zmq_send(socket, identifier.ptr, identifier.length, ZMQ_SNDMORE);
            if (rc < 0)
                return;
            rc = zmq_send(socket, null, 0, ZMQ_SNDMORE);
            if (rc < 0)
                return;
        }

        zmq_msg_t response;
        rc = zmq_msg_init_size(&response, len);
        assert(rc == 0);
        scope(exit)
            zmq_msg_close(&response);

        zmq_msg_data(&response)[0..len] = cast(void[])resData[0..len];
        rc = zmq_msg_send(&response, socket, 0);
    }
}
