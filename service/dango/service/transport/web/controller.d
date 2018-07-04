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
    import dango.system.container : registerNamed;
    import dango.system.component;

    import dango.web.controller;
    import dango.service.protocol;
}


/**
 * Класс контроллера RPC
 */
class RPCWebController : NamedBaseWebController!"RPC"
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

        super((HTTPServerRequest req, HTTPServerResponse res) {
                () @trusted {
                    auto data = protocol.handle(cast(immutable)req.bodyReader.readAll());
                    res.writeBody(data);
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
class RPCWebControllerFactory : ComponentFactory!(WebController)
{
    private
    {
        ApplicationContainer _container;
        ServerProtocol _protocol;
    }


    this(ServerProtocol protocol, ApplicationContainer container)
    {
        this._container = container;
        this._protocol = protocol;
    }


    override RPCWebController create(Properties config)
    {
        auto entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint in configuration transport web");

        auto ret = new RPCWebController(_protocol, entrypoint);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }


    Registration registerFactory()
    {
        enum NAME = RPCWebController.NAME;
        return _container.registerNamed!(ComponentFactory!(WebController),
                RPCWebControllerFactory, NAME).existingInstance(this);
    }
}

