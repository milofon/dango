/**
 * Модуль содержит реализацию функций и типов данных для ошибок RPC протокола
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-18
 */

module dango.service.protocol.rpc.error;

private
{
    import std.meta;

    import uninode.core : UniNode;
    import uninode.serialization : serializeToUniNode;
}


/**
 * Предопределенные коды ошибок
 */
enum ErrorCode
{
    PARSE_ERROR = -32700,
    INVALID_REQUEST = -32600,
    METHOD_NOT_FOUND = -32601,
    INVALID_PARAMS = -32602,
    INTERNAL_ERROR = -32603,
    SERVER_ERROR = -32000
}


alias ErrorMessages = AliasSeq!(
        ErrorCode.PARSE_ERROR, "Parse error",
        ErrorCode.INVALID_REQUEST, "Invalid Request",
        ErrorCode.METHOD_NOT_FOUND, "Method not found",
        ErrorCode.INVALID_PARAMS, "Invalid params",
        ErrorCode.INTERNAL_ERROR, "Internal error",
        ErrorCode.SERVER_ERROR, "Server error"
    );


/**
 * Возвращает стандартное сообщение об ошибке по коду
 */
string getErrorMessageByCode(ErrorCode code)
{
    switch (code)
    {
        // pragma (msg, GenerateErrorSwitch!(ErrorMessages));
        mixin(GenerateErrorSwitch!(ErrorMessages));
        default:
            return "Server error";
    }
}


/**
 * Ошибка Rpc
 */
class RpcException : Exception
{
    private
    {
        int _code;
        UniNode _data;
    }


    this(int code, string message, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null)
    {
        this._code = code;
        super(message, file, line, next);
    }


    this(ErrorCode code, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null)
    {
        this._code = cast(int)code;
        super(getErrorMessageByCode(code), file, line, next);
    }


    this(int code, string message, UniNode data, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null)
    {
        this._code = code;
        this._data = data;
        super(message, file, line, next);
    }


    this(ErrorCode code, UniNode data, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null)
    {
        this._code = cast(int)code;
        this._data = data;
        super(getErrorMessageByCode(code), file, line, next);
    }


    int code() @property
    {
        return _code;
    }


    UniNode data() @property
    {
        return _data;
    }
}



void enforceRpc(V)(V value, int code, string message, string file = __FILE__,
        size_t line = __LINE__)
{
    if (!!value)
        return;

    throw new RpcException(code, message, file, line);
}



void enforceRpcData(V, T)(V value, int code, string message, T data,
        string file = __FILE__, size_t line = __LINE__)
{
    if (!!value)
        return;

    throw new RpcException(code, message, serializeToUniNode!T(data), file, line);
}



@system unittest
{
    import std.exception;
    assertThrown!RpcException(enforceRpcData(false, 100, "no", "no"));
}



private:



template GenerateErrorSwitch(M...)
{
    static if (M.length > 1)
    {
        enum GenerateErrorSwitch = "case ErrorCode." ~ M[0].stringof ~ ":\n"
            ~ "return \"" ~ M[1] ~ "\";\n" ~ GenerateErrorSwitch!(M[2..$]);
    }
    else
        enum GenerateErrorSwitch = "";
}

