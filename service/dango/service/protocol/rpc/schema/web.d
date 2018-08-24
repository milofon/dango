/**
 * Модуль web контроллера подсистемы документации RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-12
 */

module dango.service.protocol.rpc.schema.web;

private
{
    import std.zip;
    import std.format : fmt = format;
    import std.conv : to;

    import vibe.http.server : render;

    import dango.system.application : Application;
    import dango.system.container : Autowire;
    import dango.system.properties : getOrEnforce;

    import dango.web.controller;
}


enum DANGO_DOC_DIST = import("dist.zip");


/**
 * Класс контроллера позволяющий отобразить документацию
 */
class RpcDocumentationWebController : BaseWebController
{
    @Autowire
    Application _application;


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


    void registerChains(ChainRegisterCallback dg)
    {
        dg(new RpcDocChain(_path, _entrypoint,
                    _application.name, _application.release.to!string));
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


    this(string path, string entrypoint, string title, string release)
    {
        this._path = path;

        struct Dist
        {
            string appJs;
            string vendorJs;
            string appCss;
        }

        Dist dist;

        auto zip = new ZipArchive(cast(ubyte[])DANGO_DOC_DIST);
        foreach (name, am; zip.directory)
        {
            zip.expand(am);
            switch (name)
            {
                case "app.js":
                    dist.appJs = cast(string)am.expandedData;
                    break;
                case "chunk-vendors.js":
                    dist.vendorJs = cast(string)am.expandedData;
                    break;
                case "app.css":
                    dist.appCss = cast(string)am.expandedData;
                    break;
                default:
                    break;
            }
        }

        registerChainHandler((scope HTTPServerRequest req, scope HTTPServerResponse res){
                res.render!("documentation.dt", req, entrypoint, dist, title, release);
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
class RpcDocumentationWebControllerFactory : BaseWebControllerFactory
{
    override RpcDocumentationWebController createController(Properties config)
    {
        string path = config.getOrEnforce!string("path",
                "Not defined path parameter");
        string entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint parameter");
        return new RpcDocumentationWebController(path, entrypoint);
    }
}

