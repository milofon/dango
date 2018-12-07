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
    import dango.service.protocol.rpc.error : enforceRpc, enforceRpcData;
}

private
{
    import std.meta : Alias, AliasSeq;
    import std.functional : toDelegate;
    import std.typecons : Tuple;
    import std.traits;

    import uniconf.core : Config;
    import uninode.core : UniNode;
    import poodinis : Registration;

    import dango.system.container;
    import dango.system.traits;

    import dango.service.protocol.rpc.core;
    import dango.service.protocol.rpc.error;
    import dango.service.protocol.rpc.schema.recorder;
    import dango.service.serialization;
}


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
 * Функция регистрации обработчика запроса
 */
alias RegisterHandlerCallback = void delegate(string, MethodHandler);


/**
 * Интерфейс контроллера
 */
interface RpcController : ActivatedComponent
{
    /**
     * Регистрация обработчиков в диспетчер
     * На каждый обработчик формируется вызов dg
     * Params:
     * dg = Функция регистрации цепочки
     */
    void registerHandlers(RegisterHandlerCallback hdl);

    /**
     * Регистрация документации метода
     * Params:
     * dg = Функция обработки документации
     */
    void registerSchema(SchemaRecorder recorder);
}




/**
 * Базовый класс rpc контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
abstract class GenericRpcController(IType) : RpcController, IType
{
    mixin ActivatedComponentMixin!();
    static assert(is(IType == interface),
            IType.stringof ~ " is not interface");

    static assert(hasUDA!(IType, Controller),
            IType.stringof ~ " is not marked with a Controller");


    void registerHandlers(RegisterHandlerCallback hdl)
    {
        alias Handlers = GetRpcControllerMethods!IType;
        static assert(Handlers.length, "The controller must contain handlers");
        foreach(Member; Handlers)
        {
            enum udas = getUDAs!(Member, Method);
            enum fName = __traits(identifier, Member);
            auto HDL = GenerateHandlerFromMethod!(
                    __traits(getMember, this, fName))(
                    &__traits(getMember, this, fName));
            hdl(FullMethodName!(IType, udas[0].method), HDL);
        }
    }


    void registerSchema(SchemaRecorder recorder)
    {
        alias Handlers = GetRpcControllerMethods!IType;
        static assert(Handlers.length, "The controller must contain handlers");
        foreach(Member; Handlers)
        {
            enum udas = getUDAs!(Member, Method);
            enum name = FullMethodName!(IType, udas[0].method);
            recorder.registerSchema!(IType, name, Member)();
        }
    }
}


/**
 * Базовая фабрика для RPC контроллеров
 * Params:
 * CType = Тип контроллера
 */
abstract class RpcControllerFactory : ComponentFactory!(RpcController, Config)
{
    RpcController createController(Config config);


    RpcController createComponent(Config config)
    {
        auto ret = createController(config);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
}


/**
 * Регистрация компонента RPC контроллер
 */
Registration registerController(C : RpcController, F : RpcControllerFactory, string N)(
        ApplicationContainer container)
{
    return container.registerNamedFactory!(C, N, F);
}


/**
 * Регистрация компонента RPC контроллер
 */
Registration registerController(C : RpcController, string N)(ApplicationContainer container)
{
    class RpcControllerCtorFactory : RpcControllerFactory
    {
        override RpcController createController(Config config)
        {
            return new C(config);
        }
    }

    auto factory = new RpcControllerCtorFactory();
    return container.registerNamedExistingFactory!(C, N)(factory);
}


/**
 * Возвращает список обработчиков контроллера
 * Params:
 * C = Проверяемый тип
 */
private template GetRpcControllerMethods(C)
{
    private template Get(NList...)
    {
        static if (NList.length == 0)
            alias Get = AliasSeq!();
        else static if (NList.length == 1)
        {
            static if(IsPublicMember!(C, NList[0]))
            {
                alias Member = Alias!(__traits(getMember, C, NList[0]));
                static if (isCallable!Member && getUDAs!(Member, Method).length)
                    alias Get = AliasSeq!(__traits(getMember, C, NList[0]));
                else
                    alias Get = AliasSeq!();
            }
            else
                alias Get = AliasSeq!();
        }
        else
            alias Get = AliasSeq!(
                    Get!(NList[0 .. $/2]),
                    Get!(NList[$/2.. $]));
    }

    alias GetRpcControllerMethods = Get!(__traits(allMembers, C));
}


/**
 * Возвращает полное наименование команды
 */
private template FullMethodName(I, string method)
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


/**
 * Генерация обработчика на основе функции
 */
private template GenerateHandlerFromMethod(alias F)
{
    alias ParameterIdents = ParameterIdentifierTuple!F;
    alias ParameterTypes = ParameterTypeTuple!F;
    alias ParameterDefs = ParameterDefaults!F;
    alias Type = typeof(toDelegate(&F));
    alias RT = ReturnType!F;
    alias PT = Tuple!ParameterTypes;

    MethodHandler GenerateHandlerFromMethod(Type hdl)
    {
        bool[string] requires; // обязательные поля

        static if (ParameterTypes.length == 1 && is(ParameterTypes[0] == UniNode))
            UniNode fun(UniNode params)
            {
                static if (is(RT == void))
                {
                    hdl(params);
                    return UniNode();
                }
                else
                {
                    RT ret = hdl(params);
                    static if (is(RT == UniNode))
                        return ret;
                    else
                        return serializeToUniNode!RT(ret);
                }
            }
        else
            UniNode fun(UniNode params)
            {
                if (!(params.kind == UniNode.Kind.object
                            || params.kind == UniNode.Kind.array
                            || params.kind == UniNode.Kind.nil))
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
                        args[idx] = deserializeUniNode!(PType)(value);
                    catch (Exception e)
                        paramErrors[key] ~= e.msg;
                }

                // заполняем аргументы
                foreach(i, key; ParameterIdents)
                {
                    alias PType = ParameterTypes[i];
                    if (params.kind == UniNode.Kind.object)
                    {
                        if (auto v = key in params)
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
                    else if (params.kind == UniNode.Kind.array)
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
                        UniNode[] errArr;
                        foreach (v; errs)
                            errArr ~= UniNode(v);
                        errObj[k] = UniNode(errArr);
                    }

                    throw new RpcException(ErrorCode.INVALID_PARAMS, UniNode(errObj));
                }

                static if (is(RT == void))
                {
                    hdl(args.expand);
                    return UniNode();
                }
                else
                {
                    RT ret = hdl(args.expand);
                    static if (is(RT == UniNode))
                        return ret;
                    else
                        return serializeToUniNode!RT(ret);
                }
            }

        return &fun;
    }
}

