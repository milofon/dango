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
    import std.format : fmt = format;
    import std.file : exists;

    import vibe.http.fileserver;

    import dango.system.container;
    import dango.system.properties;
    import dango.web.controller;
}


/**
 * Класс контроллера позволяющий раздавать статику из директории
 */
class FileShareWebController : BaseWebController
{
    private
    {
        string _directory;
    }


    this(string directory)
    {
        this._directory = directory;
    }


    void registerChains(RegisterChainCallback dg)
    {
        auto fsettings = new HTTPFileServerSettings;
        fsettings.serverPathPrefix = prefix;

        auto urlPath = prefix.endsWith("*") ? prefix : prefix ~ "*";
        dg(HTTPMethod.GET, urlPath, new Chain(serveStaticFiles(_directory, fsettings)));
    }
}


/**
 * Класс фабрика контроллера позволяющий раздавать статику из директории
 */
class FileShareWebControllerFactory : WebControllerFactory
{
    override FileShareWebController createController(Config config)
    {
        string directory = config.getOrEnforce!string("directory",
                "Not defined 'directory' parameter");
        enforceConfig(directory.exists, fmt!"Not exists directory '%s'"(directory));
        return new FileShareWebController(directory);
    }
}

