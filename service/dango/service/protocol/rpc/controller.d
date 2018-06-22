/**
 * Модуль общих абстракций контроллера RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.protocol.rpc.controller;

public
{
    import proped : Properties;

    import dango.service.serialization : Serializer;
}

private
{
    import std.traits;
    import std.meta : Alias;
    import std.format : fmt = format;
    import std.typecons : Tuple;
    import std.functional : toDelegate;

    import vibe.core.log : logInfo;

    import dango.system.traits;

    import dango.service.global;
    import dango.service.serialization : UniNode,
           marshalObject, unmarshalObject;
    import dango.service.protocol.rpc.error;
}


/**
 * Функция обработки запроса
 */
alias Handler = UniNode delegate(UniNode params);


/**
 * Функция регистрации обработчика запроса
 */
alias RegisterHandler = void delegate(string, Handler);


/**
 * Аннотация контроллера
 */
struct Controller
{
    string prefix;
}


/**
 * Аннотация метода
 */
struct Method
{
    string method;
}


/**
 * Интерфейс контроллера
 */
interface RpcController : Configurable!(Serializer, Properties), Activated
{
    /**
     * Регистрация обработчиков в диспетчер
     * Params:
     * dispatcher = Диспетчер
     */
    void register(RegisterHandler hdl);
}


/**
  * Базовый класс для контроллеров
  * Params:
  * P = Тип потомка
  */
abstract class BaseRpcController(P) : P, RpcController
{
    private
    {
        Serializer _serializer;
        bool _enabled;
    }


    final void configure(Serializer serializer, Properties config)
    {
        _serializer = serializer;
        _enabled = config.getOrElse!bool("enabled", false);

        controllerConfigure(config);
    }


    bool enabled() @property
    {
        return _enabled;
    }


    void register(RegisterHandler hdl)
    {
        eachControllerMethods!P(cast(P)this, hdl);
    }


protected:


    void controllerConfigure(Properties config) {}


    void enforceRpc(V)(V value, int code, string message,
            string file = __FILE__, size_t line = __LINE__)
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

        throw new RpcException(code, message, marshalObject!T(data), file, line);
    }
}


/**
 * Возвращает полное наименование команды
 */
template FullMethodName(I, string method)
{
    enum udas = getUDAs!(I, Controller);
    static if (udas.length > 0)
    {
        enum prefix = udas[0].prefix;
        static if (prefix.length > 0)
            enum FullMethodName = prefix ~ "." ~ method;
        else
            enum FullMethodName = method;
    }
    else
        enum FullMethodName = method;
}


private:


void eachControllerMethods(C)(C controller, RegisterHandler hdl)
{
    foreach (string fName; __traits(allMembers, C))
    {
        static if(IsPublicMember!(C, fName))
        {
            alias member = Alias!(__traits(getMember, C, fName));
            enum udas = getUDAs!(member, Method);

            static if (isCallable!member && udas.length > 0)
            {
                auto HDL = GenerateHandlerFromMethod!(
                        __traits(getMember, controller, fName))(
                        &__traits(getMember, controller, fName));
                hdl(FullMethodName!(C, udas[0].method), HDL);
            }
        }
    }
}


template GenerateHandlerFromMethod(alias F)
{
    alias ParameterIdents = ParameterIdentifierTuple!F;
    alias ParameterTypes = ParameterTypeTuple!F;
    alias ParameterDefs = ParameterDefaults!F;
    alias Type = typeof(toDelegate(&F));
    alias RT = ReturnType!F;
    alias PT = Tuple!ParameterTypes;

    Handler GenerateHandlerFromMethod(Type hdl)
    {
        bool[string] requires; // обязательные поля

        UniNode fun(UniNode params)
        {
            if (!(params.type == UniNode.Type.object
                        || params.type == UniNode.Type.array
                        || params.type == UniNode.Type.nil))
                throw new RpcException(ErrorCode.INVALID_PARAMS);

            string[][string] paramErrors;

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

            void fillArg(size_t idx, PType)(string key, UniNode value)
            {
                try
                    args[idx] = unmarshalObject!(PType)(value);
                catch (Exception e)
                    paramErrors[key] ~= "Got type %s, expected %s".fmt(
                            value.type, typeid(PType));
            }

            // заполняем аргументы
            foreach(i, key; ParameterIdents)
            {
                alias PType = ParameterTypes[i];
                if (params.type == UniNode.Type.object)
                {
                    auto pObj = params.via.map;
                    if (auto v = key in pObj)
                    {
                        fillArg!(i, PType)(key, *v);
                        requires[key] = true;
                    }
                    else
                    {
                        if (ParameterIdents.length == 1 && isAggregateType!PType)
                        {
                            fillArg!(i, PType)(key, params);
                            requires[key] = true;
                        }
                    }
                }
                else if (params.type == UniNode.Type.array)
                {
                    UniNode[] aParams = params.get!(UniNode[]);
                    if (isArray!PType && ParameterIdents.length == 1)
                    {
                        fillArg!(i, PType)(key, params);
                        requires[key] = true;
                    }
                    else if (i < aParams.length)
                    {
                        UniNode v = aParams[i];
                        fillArg!(i, PType)(key, v);
                        requires[key] = true;
                    }
                }
            }

            // генерируем ошибку об обязательных полях
            foreach (k, v; requires)
            {
                if (v == false)
                    paramErrors[k] ~= "is required";
            }

            if (paramErrors.length > 0)
            {
                UniNode[string] errObj;
                foreach (k, errs; paramErrors)
                {
                    logInfo("%s -> %s", k, errs);
                    UniNode[] errArr;
                    foreach (v; errs)
                        errArr ~= UniNode(v);
                    errObj[k] = UniNode(errArr);
                }

                throw new RpcException(ErrorCode.INVALID_PARAMS, UniNode(errObj));
            }

            RT ret = hdl(args.expand);
            return marshalObject!RT(ret);
        }

        return &fun;
    }
}

