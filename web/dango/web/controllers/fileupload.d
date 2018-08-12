/**
 * Модуль контроллера для загрузки файлов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-08-09
 */

module dango.web.controllers.fileupload;

private
{
    import std.uuid : randomUUID;
    import std.path : buildPath, baseName, extension, setExtension;
    import std.file : mkdirRecurse, exists;

    import vibe.core.file : copyFile, NativePath;
    import vibe.data.json;
    import vibe.inet.mimetypes : getMimeTypeForFile;

    import dango.system.properties : getOrEnforce;
    import dango.system.container;
    import dango.web.controller;
}



@Controller("")
interface IFileUpload
{
    @Handler("/upload", HTTPMethod.POST)
    void upload(HTTPServerRequest req, HTTPServerResponse res) @safe;
}


/**
 * Класс контроллера позволяющий загружать файлы
 */
class FileUploadWebController : GenericWebController!(
        FileUploadWebController, IFileUpload)
{
    private
    {
        string _path;
    }


    this(string path)
    {
        this._path = path;
        if (!path.exists)
            mkdirRecurse(path);
    }


    void upload(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        Json ret = Json.emptyArray();
        foreach (key, value; req.files)
        {
            string fileId = randomUUID.toString;
            string fileName = value.filename.name;
            string fileExt = fileName.baseName.extension;
            string newPath = buildPath(_path, fileId)
                .setExtension(fileExt);

            copyFile(value.tempPath, NativePath(newPath));

            Json item = Json.emptyObject();
            item["key"] = key;
            item["name"] = fileName;
            item["mime"] = getMimeTypeForFile(fileName);
            item["id"] = fileId;
            ret ~= item;
        }

        res.writeJsonBody(Json(["files": ret]));
    }


    HTTPServerRequestDelegate createHandler(HandlerType, alias Member)(HandlerType hdl)
    {
        return hdl;
    }
}


/**
 * Класс фабрика контроллера позволяющий загружать файлы
 */
class FileUploadWebControllerFactory : BaseWebControllerFactory!("UPLOAD")
{
    WebController createComponent(Properties config)
    {
        string path = config.getOrEnforce!string("path",
                "Not defined path parameter");
        return new FileUploadWebController(path);
    }
}

