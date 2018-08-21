/**
 * Модуль контроллера RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-04
 */

module dango.service.transport.web.controller;

private
{
    import poodinis : Registration, existingInstance;

    import vibe.stream.operations : readAll;

    import dango.system.properties : getOrEnforce;
    import dango.system.container;

    import dango.web.controller;
    import dango.service.protocol;
}


/**
 * Класс контроллера RPC
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


    void registerChains(ChainRegister dg)
    {
        dg(new RpcChain(_protocol, _entrypoint));
    }
}


/**
 * Цепочка обработки запроса для загрузки файла
 */
class RpcChain : BaseChain
{
    private string _entrypoint;


    this(ServerProtocol protocol, string entrypoint)
    {
        this._entrypoint = entrypoint;

        string contentType;
        switch (protocol.serializer.name)
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

        pushHandler((HTTPServerRequest req, HTTPServerResponse res) {
                () @trusted {
                    auto data = protocol.handle(cast(immutable)req.bodyReader.readAll());
                    res.writeBody(data, contentType);
                } ();
            });
    }


    HTTPMethod method() @property
    {
        return HTTPMethod.POST;
    }


    string path() @property
    {
        return _entrypoint;
    }


    void attachMiddleware(WebMiddleware mdw)
    {
        pushMiddleware(mdw);
    }
}


/**
 * Класс фабрика контроллера позволяющий раздавать статику из директории
 */
class RpcWebControllerFactory : ComponentFactory!(WebController), Named
{
    mixin NamedMixin!"RPC";

    private ServerProtocol _protocol;


    this(ServerProtocol protocol)
    {
        this._protocol = protocol;
    }


    WebController createComponent(Properties config)
    {
        auto entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint in configuration transport web");

        auto ret = new RpcWebController(_protocol, entrypoint);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
}

