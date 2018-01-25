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
}


struct RPCController
{
    string prefix;
}


struct RPCHandler
{
    string method;
}


interface Controller
{
    /**
     * Инициализация контроллера
     * Params:
     *
     * config = Конфигурация контроллера
     */
    void initialize(Properties config);


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


abstract class BaseController(P) : Controller
{
    private
    {
        bool _enabled;
        DispatcherType _dtype;
    }


    final void initialize(Properties config)
    {
        _enabled = config.getOrElse!bool("enabled", false);
        doInitialize(config);
    }


    bool enabled() @property
    {
        return _enabled;
    }


    void register(Dispatcher dispatcher)
    {
        _dtype = dispatcher.type;
        final switch (_dtype) with (DispatcherType)
        {
            case MSGPACK:
                import dango.service.dispatcher.msgpack;
                registerControllerHandlers!(P, MsgPackDispatcher)
                    (cast(P)this, cast(MsgPackDispatcher)dispatcher);
                break;
            case JSON:
                import dango.service.dispatcher.json;
                registerControllerHandlers!(P, JsonDispatcher)
                    (cast(P)this, cast(JsonDispatcher)dispatcher);
                break;
        }
    }

protected:

    void doInitialize(Properties config);


    void enforceRPC(V, T)(V value, int code, string message, T data = T.init,
            string file = __FILE__, size_t line = __LINE__)
    {
        if (!!value)
            return;

        final switch (_dtype) with (DispatcherType)
        {
            case MSGPACK:
                import dango.service.dispatcher.msgpack;
                MsgPackDispatcher.enforceRPC!T(code, message, data, file, line);
                break;
            case JSON:
                import dango.service.dispatcher.json;
                JsonDispatcher.enforceRPC!T(code, message, data, file, line);
                break;
        }
    }
}


void registerControllerHandlers(C, D)(C controller, D dispatcher)
{
    template IsAccesable(string N)
    {
        enum access = __traits(getProtection, __traits(getMember, C, N));
        enum IsAccesable = access == "public";
    }

    string getFullMethod(string method)
    {
        enum udas = getUDAs!(C, RPCController);
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
                    static if (is(typeof(attr) == RPCHandler))
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
