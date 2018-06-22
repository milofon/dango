/**
 * Модуль содержит компонент протокола REST
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-18
 */

module dango.service.protocol.rest.proto;

private
{
    import std.string : strip;
    import std.format : fmt = format;

    import vibe.core.log;
    import vibe.http.router : URLRouter;
    import vibe.http.server : HTTPServerRequestDelegate;

    import dango.system.properties : getNameOrEnforce, configEnforce;
    import dango.system.container : resolveNamed;

    import dango.service.serialization;
    import dango.service.protocol.core;
    import dango.service.protocol.rest.controller;
}


/**
 * Объект ошибки JsonAPI
 */
struct ErrorObject
{
    int id;
    int status;
    string title;
    string detail;
}


/**
 * Проткол на основе REST
 */
class RESTServerProtocol : BaseServerProtocol!HTTPServerProtocol
{
    private
    {
        URLRouter _router;
    }


    this()
    {
        _router = new URLRouter();
    }


    override void protoConfigure(ApplicationContainer container, Properties config)
    {
        foreach (Properties ctrConf; config.getArray("controller"))
        {
            string ctrName = getNameOrEnforce(ctrConf,
                    "Not defined controller name");

            RestController ctrl = container.resolveNamed!RestController(ctrName);
            configEnforce(ctrl !is null, fmt!"Controller '%s' not register"(ctrName));

            ctrl.configure(ctrConf);

            if (ctrl.enabled)
            {
                ctrl.register(&registerHandler);
                logInfo("Register controller '%s' from '%s'", ctrName, ctrl);
            }
        }
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        _router.handleRequest(req, res);
    }


    void registerHandler(HTTPMethod method, string path, HTTPServerRequestDelegate hdl)
    {
        _router.match(method, path, createHandler(hdl));
        logInfo("Register path (%s : %s)", method, path);
    }


protected:


    void writeErrorBody(HTTPServerResponse res, int status, ErrorObject[] errors) @safe
    {
        auto contentType = () @trusted {
            return (serializer.name == "JSON") ?
                "application/json; charset=UTF-8" : "application/octet-stream";
        } ();

        auto content = () @trusted {
            UniNode[] errs;
            foreach (ErrorObject eo; errors)
                errs ~= marshalObject!ErrorObject(eo);
            return serializer.serialize(UniNode(["errors": UniNode(errs)]));
        } ();

        res.writeBody(content, status, contentType);
    }


private:


    HTTPServerRequestDelegate createHandler(HTTPServerRequestDelegate hdl)
    {
        return (HTTPServerRequest req, HTTPServerResponse res) @safe
        {
            try
                hdl(req, res);
            catch (Exception e)
            {
                logError("Внутренняя ошибка сервера: %s", e.msg);
                if (!res.headerWritten)
                    writeErrorBody(res, 500, [
                        ErrorObject(500, 500, "Внутренняя ошибка сервера", e.msg)
                    ]);
            }
        };
    }
}

