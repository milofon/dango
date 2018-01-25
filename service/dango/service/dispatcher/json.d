/**
 * Диспетчер оперирующий сообщениями в формате JSON
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.dispatcher.json;

private
{
    import std.format : fmt = format;
    import std.array : appender;
    import std.string : strip;
    import std.functional : toDelegate;
    import std.typecons : Tuple;
    import std.traits;

    import vibe.data.json;
    import vibe.core.log;

    import dango.service.dispatcher.core;
}


alias JsonRPCErrors = RPCErrors!Json;
alias JsonHandler = ubyte[] delegate(Json* id, Json params);


class JsonDispatcher : Dispatcher
{
    private JsonHandler[string] _handlers;


    DispatcherType type() @property
    {
        return DispatcherType.JSON;
    }


    ubyte[] handle(ubyte[] data) nothrow
    {
        auto bodyStr = cast(string)data;
        Json json;
        try
            json = parseJson(bodyStr);
        catch (Exception e)
            return createErrorBody(JsonRPCErrors.PARSE_ERROR);


        string method;
        Json* id;
        Json params;

        try
        {
            id = "id" in json;

            auto vMethod = "method" in json;
            if (!vMethod || vMethod.type != Json.Type.string)
                return createErrorBody(JsonRPCErrors.INVALID_REQUEST);
            method = (*vMethod).get!string.strip();

            params = Json.emptyObject();
            if (auto vParams = "params" in json)
                params = (*vParams);
        }
        catch (Exception e)
            return createErrorBody(RPCError!Json(
                        500, e.msg));

        if (auto hdl = method in _handlers)
        {
            try
                return (*hdl)(id, params);
            catch (RPCException!Json e)
                return createErrorBody(e.error);
            catch (Exception e)
                return createErrorBody(RPCError!Json(
                        500, e.msg));
        }
        else
            return createErrorBody(JsonRPCErrors.METHOD_NOT_FOUND);
    }


    void registerHandler(string cmd, JsonHandler h)
    {
        _handlers[cmd] = h;
        logInfo("Register method (%s)", cmd);
    }


    template generateHandler(alias F)
    {
        alias ParameterIdents = ParameterIdentifierTuple!F;
        alias ParameterTypes = ParameterTypeTuple!F;
        alias ParameterDefs = ParameterDefaults!F;
        alias Type = typeof(toDelegate(&F));
        alias RT = ReturnType!F;
        alias PT = Tuple!ParameterTypes;

        JsonHandler generateHandler(Type hdl)
        {
            bool[string] requires; // обязательные поля

            ubyte[] fun(Json* id, Json params)
            {
                if (!(params.type == Json.Type.object
                        || params.type == Json.Type.array))
                    return createErrorBody(JsonRPCErrors.INVALID_PARAMS);

                // инициализируем обязательные поля
                PT args;
                foreach (i, def; ParameterDefs)
                {
                    string key = ParameterIdents[i];
                    static if (is(def == void))
                        requires[key] = false;
                    else
                        args[i] = def;
                }

                foreach(i, key; ParameterIdents)
                {
                    alias PType = ParameterTypes[i];
                    if (params.type == Json.Type.object)
                    {
                        if (auto v = key in params)
                        {
                            try
                                args[i] = deserializeJson!(PType)(*v);
                            catch (Exception e)
                                return createErrorBody(RPCError!Json(
                                        -32602,
                                        "Parameter '%s' is invalid".fmt(key)
                                    ));
                            requires[key] = true;
                        }
                    }
                    else if (params.type == Json.Type.array)
                    {
                        if (isArray!PType)
                        {
                            try
                                args[i] = deserializeJson!(PType)(params);
                            catch (Exception e)
                                return createErrorBody(RPCError!Json(
                                        -32602,
                                        "Parameter '%s' is invalid".fmt(key)
                                    ));
                            requires[key] = true;
                        }
                        else if (i < params.length)
                        {
                            Json v = params[i];
                            try
                                args[i] = deserializeJson!(PType)(v);
                            catch (Exception e)
                                return createErrorBody(RPCError!Json(
                                        -32602,
                                        "Parameter '%s' is invalid".fmt(key)
                                    ));
                            requires[key] = true;
                        }
                    }
                }

                Json needSet = Json.emptyArray();
                foreach (k, v; requires)
                {
                    if (v == false)
                        needSet ~= Json(k);
                }

                if (needSet.length > 0)
                    return createErrorBody(RPCError!Json(
                            400,
                            "Required fields are not filled",
                            needSet
                        ));

                RT ret = hdl(args.expand);
                return createResultBody(id, serializeToJson!RT(ret));
            }
            return &fun;
        }
    }

    static void enforceRPC(T)(int code, string message, T data = T.init,
            string file = __FILE__, size_t line = __LINE__)
    {
        auto error = RPCError!Json(code, message, serializeToJson!T(data));
        throw new RPCException!Json(error, file, line);
    }
}


private:


ubyte[] createErrorBody(RPCError!Json error) nothrow
{
    auto ret = appender!(string);
    // Json response = Json.emptyObject();
    // response["jsonrpc"] = "2.0";
    // response["id"] = null;

    // Json err = Json.emptyObject();
    // err["code"] = error.code;
    // err["message"] = error.message;
    // if (error.data.type != Json.Type.undefined)
    //     err["data"] = error.data;
    // response["error"] = err;

    // serializeToJson(ret, response);
    return cast(ubyte[])ret.data;
}


ubyte[] createResultBody(Json* id, Json result) nothrow
{
    if (id is null)
        return [];

    auto ret = appender!(string);
    // Json response = Json([
    //         "jsonrpc": Json("2.0"),
    //         "id": *id,
    //         "result": result
    // ]);
    // serializeToJson(ret, response);
    return cast(ubyte[])ret.data;
}
