/**
 * Модуль контроллера раздающего файлы
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-03
 */

module dango.web.controllers.files;

private
{
    import std.algorithm.searching : endsWith;

    import dango.system.properties : getOrEnforce;
    import dango.system.component;

    import vibe.http.fileserver;

    import dango.web.controller;
}


/**
 * Класс контроллера позволяющий раздавать статику из директории
 */
class FilesWebController : NamedBaseWebController!"FILES"
{
    private
    {
        string _path;
        string _prefix;
    }


    this(string path, string prefix)
    {
        this._path = path;
        this._prefix = prefix;
    }


    void registerChains(ChainRegister dg)
    {
        dg(new FilesChain(_path, _prefix));
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
        fsettings.serverPathPrefix = _prefix;

        super(serveStaticFiles(path, fsettings));
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
class FilesWebControllerFactory : AutowireComponentFactory!(WebController,
        FilesWebController)
{
    this(ApplicationContainer container)
    {
        super(container);
    }


    override FilesWebController create(Properties config)
    {
        string path = config.getOrEnforce!string("path",
                "Not defined path parameter");
        string prefix = config.getOrEnforce!string("prefix",
                "Not defined prefix parameter");

        auto ret = new FilesWebController(path, prefix);
        container.autowire(ret);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
}

