/**
 * Основной модуль диспетчера
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.dispatcher.core;


alias Handler = ubyte[] delegate(ubyte[]) nothrow;


struct RPCError(T)
{
    int code;
    string message;
    T data;
}


RPCError!T createErrorByCode(T)(int code)
{
    RPCError!T result;
    result.code = code;
    switch (code)
    {
        case -32700:
            result.message = "Parse error";
            break;
        case -32600:
            result.message = "Invalid Request";
            break;
        case -32601:
            result.message = "Method not found";
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


template RPCErrors(T)
{
    enum RPCErrors
    {
        PARSE_ERROR = createErrorByCode!T(-32700),
        INVALID_REQUEST = createErrorByCode!T(-32600),
        METHOD_NOT_FOUND = createErrorByCode!T(-32601),
        INVALID_PARAMS = createErrorByCode!T(-32602),
        INTERNAL_ERROR = createErrorByCode!T(-32603),
    }
}


enum DispatcherType
{
    MSGPACK,
    JSON
}


interface Dispatcher
{
    DispatcherType type() @property;

    ubyte[] handle(ubyte[]) nothrow;
}


class RPCException(T) : Exception
{
    private RPCError!T _error;


    this(RPCError!T error, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        _error = error;
        super(error.message, file, line, next);
    }


    RPCError!T error() @property nothrow
    {
        return _error;
    }
}
