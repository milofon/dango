/**
 * Диспетчер оперирующий сообщениями в формате MessagePack
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

jjdule dango.service.dispatcher.msgpack;

private
{
    import std.string : strip;
    import std.functional : toDelegate;
    import std.array : appender;
    import std.typecons : Tuple;
    import std.traits;

    import vibe.core.log;

    import msgpack;

    import dango.service.dispatcher.core;
}


alias MsgPackRPCError = RPCError!Value;
alias MsgPackHandler = ubyte[] delegate(Value* id, Value params);


class MsgPackDispatcher : Dispatcher
{
    ubyte[] handle(ubyte[] data) nothrow
    {
        // if (val.type != Value.Type.map)
        //     return createErrorBody!ubyte(MsgPackRPCErrors!ubyte.INVALID_REQUEST);

        // Value[Value] map = val.via.map;
        // string method;
        // Value *id;
        // Value params;

        // try
        // {
        //     id = Value("id") in map;

        //     auto vMethod = Value("method") in map;
        //     if (!vMethod || vMethod.type != Value.Type.raw)
        //         return createErrorBody!ubyte(MsgPackRPCErrors!ubyte.INVALID_REQUEST);
        //     method = (*vMethod).as!string.strip();

        //     params = Value(Value.Type.array);
        //     if (auto vParams = Value("params") in map)
        //         params = (*vParams);
        // }
        // catch (Exception e)
        //     return createErrorBody(RPCError!Value(
        //                 500, e.msg));

        // if (auto hdl = method in _handlers)
        // {
        //     try
        //         return (*hdl)(id, params);
        //     catch (RPCException!Value e)
        //         return createErrorBody(e.error);
        //     catch (Exception e)
        //         return createErrorBody(RPCError!Value(
        //                 500, e.msg));
        // }
        // else
        //     return createErrorBody!ubyte(MsgPackRPCErrors!ubyte.METHOD_NOT_FOUND);
        return [];
    }
}


ubyte[] createErrorBody(T)(RPCError!T error) nothrow
{
    struct ErrorResult(T)
    {
        struct Error(T)
        {
            long code;
            string message;
            T data;
        }
        long id;
        Error!T error;
    }

    auto packer = Packer(false);
    try
    {
        ErrorResult!T ret;
        ret.error.code = cast(long)error.code;
        ret.error.message = error.message;
        ret.error.data = error.data;
        // Value[Value] response;
        // response[Value("id")] = Value(null);
        // Value[Value] err;
        // err[Value("code")] = Value(cast(long)error.code);
        // err[Value("message")] = Value(error.message);
        // if (error.data.type != Value.Type.nil)
        //     err[Value("data")] = error.data;
        // response[Value("error")] = Value(err);
        // Value(response).toMsgpack(packer);
        packer.pack(ret);
    }
    catch (Exception e)
        return [];

    return packer.stream.data;
}


ubyte[] createResultBody(T)(Value* id, T data) nothrow
{
    struct Result(T)
    {
        long id;
        T result;
    }

    if (id is null)
        return [];

    auto packer = Packer(false);
    try
    {
        Result!T ret;
        ret.id = (*id).as!long;
        ret.result = data;
        packer.pack(ret);
    }
    catch(Exception e)
        return [];

    return packer.stream.data;
}
