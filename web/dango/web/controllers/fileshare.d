/**
 * Модуль контроллера раздающего файлы
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-03
 */

module dango.web.controllers.fileshare;

private
{
    import std.algorithm.searching : endsWith;

    import dango.system.properties : getOrEnforce;
    import dango.system.container;

    import vibe.http.fileserver;

    import dango.web.controller;
}


/**
 * Класс контроллера позволяющий раздавать статику из директории
 */
class FileShareWebController : NamedWebController!("SHARE")
{
    private
    {
        string _path;
    }


    this(string path)
    {
        this._path = path;
    }


    void registerChains(ChainRegisterCallback dg)
    {
        dg(new FilesChain(_path, prefix));
    }
}


/**
 * Цепочка обработки запроса для загрузки файла
 */
class FilesChain : BaseChain
{
    private
    {
        string _prefix;
    }


    this(string path, string prefix)
    {
        this._prefix = prefix;

        auto fsettings = new HTTPFileServerSettings;
        fsettings.serverPathPrefix = prefix;

        registerChainHandler(serveStaticFiles(path, fsettings));
    }


    HTTPMethod method() @property
    {
        return HTTPMethod.GET;
    }


    string path() @property
    {
        return _prefix.endsWith("*") ? _prefix : _prefix ~ "*";
    }


    void attachMiddleware(WebMiddleware mdw)
    {
        pushMiddleware(mdw);
    }
}


/**
 * Класс фабрика контроллера позволяющий раздавать статику из директории
 */
class FileShareWebControllerFactory : BaseWebControllerFactory
{
    override FileShareWebController createController(Properties config)
    {
        string path = config.getOrEnforce!string("path",
                "Not defined path parameter");
        return new FileShareWebController(path);
    }
}

