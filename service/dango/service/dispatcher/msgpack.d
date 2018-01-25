/**
 * Диспетчер оперирующий сообщениями в формате MessagePack
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.dispatcher.msgpack;

private
{
    import std.string : strip;
    import std.functional : toDelegate;
    import std.traits;

    import vibe.core.log;

    import msgpack;

    import dango.service.dispatcher.core;
}


alias MsgPackRPCErrors = RPCErrors!Value;
alias MsgPackHandler = ubyte[] delegate(Value params);


class MsgPackDispatcher : Dispatcher
{
    DispatcherType type() @property
    {
        return DispatcherType.MSGPACK;
    }


    ubyte[] handle(ubyte[] data) nothrow
    {
        Value val;
        try
        {
            auto unpacker = StreamingUnpacker(data);
            unpacker.execute();
            val = unpacker.purge();

            import std.stdio: wl = writeln;
            wl(val.type);

            return data;
        }
        catch (Exception e)
        {
            logInfo(e.msg);
            return createErrorBody(MsgPackRPCErrors.PARSE_ERROR);
        }
    }


    void registerHandler(string cmd, MsgPackHandler h)
    {

    }


    template generateHandler(alias F)
    {
        alias ParameterIdents = ParameterIdentifierTuple!F;
        alias ParameterTypes = ParameterTypeTuple!F;
        alias Type = typeof(toDelegate(&F));
        alias RT = ReturnType!F;

        MsgPackHandler generateHandler(Type hdl)
        {
            ubyte[] fun(Value params) {
                return [];
            }

            return &fun;
        }
    }


    static void enforceRPC(T)(int code, string message, T data = T.init,
            string file = __FILE__, size_t line = __LINE__)
    {

    }
}


ubyte[] createErrorBody(RPCError!Value error) nothrow
{
    // auto ret = appender!(string);
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
    // return cast(ubyte[])ret.data;

    return cast(ubyte[])"error";
}
