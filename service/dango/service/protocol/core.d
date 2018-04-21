/**
 * Общий модуль для протоколов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.core;

public
{
    import std.typecons : Nullable;

    import proped : Properties;

    import dango.service.serialization : Serializer, UniNode;
    import dango.service.dispatcher : Dispatcher;
    import dango.service.transport : ClientTransport;
}


/**
 * Интерфейс серверного Rpc протокола
 */
interface RpcServerProtocol
{
    /**
     * Инициализация протокола
     * Params:
     * dispatcher = Диспетчер вызовов
     * serializer = Сериализатор
     * config = Конфигурация протокола
     */
    void initialize(Dispatcher dispatcher, Serializer serializer, Properties config);

    /**
     * Метод-обработик входящейго запроса
     * Params:
     * data = Бинарные данные
     * Return: Ответ в бинарном виде
     */
    ubyte[] handle(ubyte[] data);
}


/**
 * Интерфейс клиентского Rpc протокола
 */
interface RpcClientProtocol
{
    /**
     * Инициализация клиентского протокола
     * Params:
     * serializer = Сериализатор
     * config = Конфигурация протокола
     */
    void initialize(Serializer serializer, ClientTransport transport);

    /**
     * Отправляет запрос удаленной команды
     * Params:
     * cmd = Команда
     * params = Параметры
     * Return: Результат выполнения удаленной команды (result)
     */
    UniNode request(string cmd, UniNode params);
}


/**
 * Сообщение об ошибке
 */
struct RpcError(T)
{
    int code;
    string message;
    Nullable!T data;
}


/**
 * Создает новое сообщение об ошибке по коду
 * Params:
 * code = Код ошибки
 */
RpcError!T createEmptyErrorByCode(T = ubyte)(int code)
{
    RpcError!T result;
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


/**
 * Создает новое сообщение об ошибке по коду с доп. данными
 * Params:
 * code = Код ошибки
 * data = Доп. данные
 */
RpcError!T createErrorByCode(T)(int code, T data)
{
    auto ret = createEmptyErrorByCode!T(code);
    ret.data = Nullable!T(data);
    return ret;
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


/**
 * Ошибка Rpc
 */
class RpcException : Exception
{
    private RpcError!UniNode _error;

    this(int code, string message, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null)
    {
        _error.code = code;
        _error.message = message;
        super(message, file, line, next);
    }


    this(int code, string message, UniNode data, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null)
    {
        _error.data = data;
        this(code, message, file, line, next);
    }


    this(RpcError!UniNode error, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        _error = error;
        super(error.message, file, line, next);
    }


    RpcError!UniNode error() @property nothrow
    {
        return _error;
    }
}
