/**
 * Модуль контроллера раздающего файлы
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-30
 */

module dango.web.controllers.fileshare;

private
{
    import std.algorithm.searching : endsWith;
    import std.format : fmt = format;

    import vibe.core.file : existsFile;
    import vibe.http.fileserver;

    import dango.system.exception : enforceConfig;
    import dango.system.properties : getOrEnforce;
    import dango.web.controller;
}


/**
 * Класс контроллера позволяющий раздавать статику из директории
 */
class FileShareWebController : WebController
{
    private
    {
        string _directory;
        string _prefix;
    }


    /**
     * Main constructor
     */
    this(string directory, string prefix) @safe
    {
        this._directory = directory;
        this._prefix = prefix;
    }

    /**
     * Регистрация цепочек маршрутов контроллера
     */
    void registerChains(RegisterChainCallback dg) @safe
    {
        auto fsettings = new HTTPFileServerSettings;
        fsettings.serverPathPrefix = _prefix;
        dg(HTTPMethod.GET, "*", new Chain(serveStaticFiles(_directory, fsettings)));
    }
}


/**
 * Класс фабрика контроллера позволяющий раздавать статику из директории
 */
class FileShareWebControllerFactory : WebControllerFactory
{
    WebController createComponent(DependencyContainer cont, UniConf config) @safe
    {
        string directory = config.getOrEnforce!string("directory",
                "Not defined 'directory' parameter");
        enforceConfig(directory.existsFile, fmt!"Not exists directory '%s'"(directory));
        string prefix = config.getOrElse("prefix", "");
        return new FileShareWebController(directory, prefix);
    }
}

