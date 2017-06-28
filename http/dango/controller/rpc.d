/**
 * Модуль с контроллером RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.controller.rpc;

private
{
    import std.traits : getUDAs;
    import std.meta : Alias;

    import vibe.data.json : Json, parseJson;
    import vibe.stream.operations : readAll;

    import vibe.http.server : HTTPServerRequest,
           HTTPServerResponse, HTTPServerRequestDelegate;
}

public
{
    import dango.controller.core;
}


/**
 * Аннотация для обозначения метода для обработки входящей команды
 * Params:
 *
 * method = RPC Метод
 */
struct RPCHandler
{
    string method;
}


/**
 * Аннотация для обозначение объекта контроллера
 * Params:
 *
 * path = Префикс для всех путей
 */
struct RPCController
{
    string path;
    string prefix;
}


struct RPCError
{
    int code;
    string message;
    uint statusCode = 500;
    Json data;
}


RPCError createErrorByCode(int code)
{
    RPCError result;
    result.code = code;
    result.statusCode = 500;
    switch (code)
    {
        case -32700:
            result.message = "Parse error";
            break;
        case -32600:
            result.message = "Invalid Request";
            result.statusCode = 400;
            break;
        case -32601:
            result.message = "Method not found";
            result.statusCode = 404;
            break;
        case -32602:
            result.message = "Invalid params";
            break;
        case -32603:
            result.message = "Internal error";
            break;
        default:
            result.message = "Server error";
            break;
    }
    return result;
}


enum RPCErrors
{
    PARSE_ERROR = createErrorByCode(-32700),
    INVALID_REQUEST = createErrorByCode(-32600),
    METHOD_NOT_FOUND = createErrorByCode(-32601),
    INVALID_PARAMS = createErrorByCode(-32602),
    INTERNAL_ERROR = createErrorByCode(-32603),
}


struct Result
{
    bool successful;
    Json data;
    RPCError error;

    this(Json data)
    {
        successful = true;
        this.data = data;
    }

    this(RPCError error)
    {
        successful = false;
        this.error = error;
    }
}


alias Handler = Result delegate(Json);

HTTPServerRequestDelegate createRPCHandler(C : Controller)(C controller)
{
    enum udas = getUDAs!(C, RPCController);
    static if (udas.length > 0)
        string path = udas[0].path;
    else
        string path = "/";

    string getFullMethod(string method)
    {
        static if (udas.length > 0)
        {
            string prefix = udas[0].prefix;
            if (prefix.length > 0)
                return prefix ~ "." ~ method;
            else
                return method;
        }
        else
            return method;
    }

    Result getResult(string method, Json params)
    {
        switch (method)
        {
            foreach (string fName; __traits(allMembers, C))
            {
                alias member = Alias!(__traits(getMember, C, fName));
                foreach (attr; __traits(getAttributes, member))
                {
                    static if (is(typeof(attr) == RPCHandler))
                    {
                        alias Type = typeof(&__traits(getMember, controller, fName));
                        static assert(is(Type == Handler), "Handler '" ~ fName ~ "' does not match the type");
                        case getFullMethod(attr.method):
                            return __traits(getMember, controller, fName)(params);
                    }
                }
            }
            default:
                return Result(createErrorByCode(-32601));
        }
    }

    void handler(HTTPServerRequest req, HTTPServerResponse res) @trusted
    {
        auto bodyStr = cast(string)req.bodyReader.readAll;
        Json json;
        try
            json = parseJson(bodyStr);
        catch (Exception e)
        {
            res.writeErrorBody(RPCErrors.PARSE_ERROR);
            return;
        }

        auto vMethod = "method" in json;
        if (!vMethod || vMethod.type != Json.Type.string)
        {
            res.writeErrorBody(RPCErrors.INVALID_REQUEST);
            return;
        }
        string method = (*vMethod).get!string;

        Json params = Json.emptyObject();
        if (auto vParams = "params" in json)
            params = (*vParams);

        Result result;
        try
            result = getResult(method, params);
        catch (Exception e)
        {
            res.writeErrorBody(RPCError(-32000, "Server error", 500));
            return;
        }

        if (!result.successful)
        {
            res.writeErrorBody(result.error);
            return;
        }

        handleCors(req, res);

        if (auto vId = "id" in json)
        {
            Json response = Json([
                "jsonrpc": Json("2.0"),
                "id": *vId,
                "result": result.data
            ]);
            res.writeJsonBody(response, 200);
            return;
        }
        else
        {
            res.writeVoidBody();
            return;
        }
    }

    return (HTTPServerRequest req, HTTPServerResponse res) @safe {
        handler(req, res);
    };
}


void writeErrorBody(HTTPServerResponse res, RPCError error) @safe
{
    Json response = Json.emptyObject();
    response["jsonrpc"] = "2.0";
    response["id"] = null;
    Json err = Json.emptyObject();
    err["code"] = error.code;
    err["message"] = error.message;

    if (error.data.type != Json.Type.undefined)
        err["data"] = error.data;

    response["error"] = err;
    res.writeJsonBody(response, error.statusCode);
}

