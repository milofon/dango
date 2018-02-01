/**
 * Модуль общих абстракций контроллера
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.controller;

public
{
    import std.meta : Alias;
    import std.traits : isCallable, getUDAs;
    import std.functional : toDelegate;

    import proped : Properties;

    import dango.service.dispatcher;
    import dango.service.serializer;
    import dango.service.protocol;
}


/**
 * Аннотация контроллера
 */
struct RpcController
{
    string prefix;
}


/**
 * Аннотация метода
 */
struct RpcHandler
{
    string method;
}


/**
 * Интерфейс контроллера
 */
interface Controller
{
    /**
     * Инициализация контроллера
     * Params:
     *
     * config = Конфигурация контроллера
     */
    void initialize(Serializer serializer, Properties config);


    /**
     * Возвращает активность контроллера
     */
    bool enabled() @property;


    /**
     * Регистрация обработчиков в диспетчер
     * Params:
     * dispatcher = Диспетчер
     */
    void register(Dispatcher dispatcher);
}


/**
  * Базовый класс для контроллеров
  * Params:
  * P = Тип потомка
  */
abstract class BaseController(P) : Controller
{
    private
    {
        Serializer _serializer;
        bool _enabled;
    }


    final void initialize(Serializer serializer, Properties config)
    {
        _enabled = config.getOrElse!bool("enabled", false);
        _serializer = serializer;
        doInitialize(config);
    }


    bool enabled() @property
    {
        return _enabled;
    }


    void register(Dispatcher dispatcher)
    {
        registerControllerHandlers!(P)(cast(P)this, dispatcher);
    }

protected:

    void doInitialize(Properties config);


    void enforceRpc(V)(V value, int code, string message,
            string file = __FILE__, size_t line = __LINE__)
    {
        if (!!value)
            return;

        RpcError!UniNode error;
        error.code = code;
        error.message = message;
        throw new RpcException(error);
    }


    void enforceRpcData(V, T)(V value, int code, string message, T data,
            string file = __FILE__, size_t line = __LINE__)
    {
        if (!!value)
            return;

        RpcError!UniNode error;
        error.code = code;
        error.message = message;
        error.data = _serializer.marshal!T(data);

        throw new RpcException(error);
    }
}


void registerControllerHandlers(C)(C controller, Dispatcher dispatcher)
{
    template IsAccesable(string N)
    {
        enum access = __traits(getProtection, __traits(getMember, C, N));
        enum IsAccesable = access == "public";
    }

    string getFullMethod(string method)
    {
        enum udas = getUDAs!(C, RpcController);
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

    foreach (string fName; __traits(allMembers, C))
    {
        static if(IsAccesable!fName)
        {
            alias member = Alias!(__traits(getMember, C, fName));
            static if (isCallable!member)
            {
                foreach (attr; __traits(getAttributes, member))
                {
                    static if (is(typeof(attr) == RpcHandler))
                    {
                        auto HDL = dispatcher.generateHandler!(
                                __traits(getMember, controller, fName))(
                                &__traits(getMember, controller, fName));
                        dispatcher.registerHandler(getFullMethod(attr.method), HDL);
                    }
                }
            }
        }
    }
}
