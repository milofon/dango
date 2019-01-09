/**
 * Модуль контроллера RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-12-05
 */

module dango.service.transport.web.controllers.websocket;

private
{
    import std.format : fmt = format;

    import vibe.http.websockets;
    import uniconf.core.exception : enforceConfig;

    import dango.system.inject;
    import dango.web.controller;

    import dango.service.protocol;
    import dango.service.protocol.core : ServerProtocolContainer;
}


/**
 * Класс web контроллера RPC
 */
class WebSocketController : BaseWebController
{
    private
    {
        string _entrypoint;
        ServerProtocol _protocol;
    }


    this(ServerProtocol protocol, string entrypoint)
    {
        this._entrypoint = entrypoint;
        this._protocol = protocol;
    }


    void registerChains(RegisterChainCallback dg)
    {
        void handleConn(scope WebSocket sock)
        {
            while (sock.connected)
            {
                auto data = _protocol.handle(cast(immutable)sock.receiveBinary(false));
                sock.send(data);
            }
        }

        dg(HTTPMethod.GET, _entrypoint, new Chain(handleWebSockets(&handleConn)));
    }
}


/**
 * Класс фабрика контроллера предоствляющего entrypoint для RPC
 */
class WebSocketControllerFactory : WebControllerFactory
{
    @Autowire
    ServerProtocolContainer protoContainer;


    override WebSocketController createController(Config config)
    {
        string protoName = config.getOrEnforce!string("protocol",
                "Not defined protocol type for rpc controller");
        auto entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint in configuration transport web");

        auto protocol = protoContainer.createProtocol(protoName);
        enforceConfig(protocol, fmt!"Protocol %s not registered"(protoName));
        return new WebSocketController(protocol, entrypoint);
    }
}

