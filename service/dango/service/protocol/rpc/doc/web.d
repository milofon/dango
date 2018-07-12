/**
 * Модуль web контроллера подсистемы документации RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-12
 */

module dango.service.protocol.rpc.doc.web;

private
{
    import vibe.http.server : render;

    import dango.system.properties : getOrEnforce;
    import dango.web.controller;
}



/**
 * Класс контроллера позволяющий отобразить документацию
 */
class RpcDocumentationWebController : BaseWebController
{
    private
    {
        string _entrypoint;
        string _path;
    }


    this(string path, string entrypoint)
    {
        this._entrypoint = entrypoint;
        this._path = path;
    }


    void registerChains(ChainRegister dg)
    {
        dg(new RpcDocChain(_path, _entrypoint));
    }
}


/**
 * Цепочка запроса документации
 */
class RpcDocChain : BaseChain
{
    private
    {
        string _path;
    }


    this(string path, string entrypoint)
    {
        this._path = path;

        super((scope HTTPServerRequest req, scope HTTPServerResponse res){
		    res.render!("documentation.dt", req, entrypoint);
        });
    }


    HTTPMethod method() @property
    {
        return HTTPMethod.GET;
    }


    string path() @property
    {
        return _path;
    }


    void attachMiddleware(WebMiddleware mdw)
    {
        pushMiddleware(mdw);
    }
}


/**
 * Класс фабрика контроллера позволяющий отобразить документацию
 */
class RpcDocumentationWebControllerFactory : BaseWebControllerFactory!("RPCDOC")
{
    WebController createComponent(Properties config)
    {
        string path = config.getOrEnforce!string("path",
                "Not defined path parameter");
        string entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint parameter");
        return new RpcDocumentationWebController(path, entrypoint);
    }
}

