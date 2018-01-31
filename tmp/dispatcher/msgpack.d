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
    private MsgPackHandler[string] _handlers;


    DispatcherType type() @property
    {
        return DispatcherType.MSGPACK;
    }


    ubyte[] handle(ubyte[] data) nothrow
    {
        // Value val;
        // try
        // {
        //     auto unpacker = StreamingUnpacker(data);
        //     unpacker.execute();
        //     val = unpacker.purge();
        // }
        // catch (Exception e)
        // {
        //     logInfo(e.msg);
        //     return createErrorBody!ubyte(MsgPackRPCErrors!ubyte.PARSE_ERROR);
        // }

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


    void registerHandler(string cmd, MsgPackHandler h)
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

        MsgPackHandler generateHandler(Type hdl)
        {
            bool[string] requires; // обязательные поля

            ubyte[] fun(Value* id, Value params)
            {
                return [];
                // if (!(params.type == Value.Type.map
                //         || params.type == Value.Type.array))
                //     return createErrorBody(MsgPackRPCErrors.INVALID_PARAMS);

                // // инициализируем обязательные поля
                // PT args;
                // foreach (i, def; ParameterDefs)
                // {
                //     string key = ParameterIdents[i];
                //     static if (is(def == void))
                //         requires[key] = false;
                //     else
                //         args[i] = def;
                // }

                // foreach(i, key; ParameterIdents)
                // {
                //     alias PType = ParameterTypes[i];

                // }

                // RT ret = hdl(args.expand);
                // return createResultBody!RT(id, ret);
            }
            return &fun;
        }
    }


    static void enforceRPC(T)(int code, string message, T data = T.init,
            string file = __FILE__, size_t line = __LINE__)
    {
        auto error = RPCError!Value(code, message, pack(data));
        throw new RPCException!Value(error, file, line);
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
