/**
 * Модуль контроллера RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-12-05
 */

module dango.service.transport.web.controllers.rpc;

private
{
    import std.format : fmt = format;

    import vibe.stream.operations : readAll;
    import uniconf.core.exception : enforceConfig;

    import dango.system.container;
    import dango.web.controller;

    import dango.service.protocol;
    import dango.service.protocol.core : ServerProtocolContainer;
}


/**
 * Класс web контроллера RPC
 */
class RpcWebController : BaseWebController
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
        string contentType;
        switch (_protocol.serializer.name)
        {
            case "JSON":
                contentType = "application/json; charset=UTF-8";
                break;
            case "MSGPACK":
                contentType = "application/msgpack";
                break;
            default:
                contentType = "application/octet-stream";
                break;
        }

        void handler (scope HTTPServerRequest req, HTTPServerResponse res) @safe
        {
            () @trusted {
                auto data = _protocol.handle(cast(immutable)req.bodyReader.readAll());
                res.writeBody(data, contentType);
            } ();
        }

        dg(HTTPMethod.POST, _entrypoint, new Chain(&handler));
    }
}


/**
 * Класс фабрика контроллера предоствляющего entrypoint для RPC
 */
class RpcWebControllerFactory : WebControllerFactory
{
    @Autowire
    ServerProtocolContainer protoContainer;


    override RpcWebController createController(Config config)
    {
        string protoName = config.getOrEnforce!string("protocol",
                "Not defined protocol type for rpc controller");
        auto entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint in configuration transport web");

        auto protocol = protoContainer.createProtocol(protoName);
        enforceConfig(protocol, fmt!"Protocol %s not registered"(protoName));
        return new RpcWebController(protocol, entrypoint);
    }
}

