/**
 * Модуль общих абстракций контроллера RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.protocol.rpc.controller;

private
{
    import std.traits;
    import std.meta : Alias, AliasSeq;
    import std.format : fmt = format;
    import std.functional : toDelegate;
    import std.typecons : Tuple;

    import vibe.core.log : logInfo;

    import dango.system.container;
    import dango.system.traits;

    import dango.service.protocol.rpc.error;
    import dango.service.serialization : UniNode,
           marshalObject, unmarshalObject;
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
 * Возвращает список обработчиков контроллера
 * Params:
 * C = Проверяемый тип
 */
template GetRpcControllerMethods(C)
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
 * Интерфейс контроллера
 */
interface RpcController : Activated
{
    /**
     * Регистрация обработчиков в диспетчер
     * На каждый обработчик формируется вызов dg
     * Params:
     * dg = Функция регистрации цепочки
     */
    void registerHandlers(RegisterHandler hdl);
}


/**
 * Базовый класс RPC контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
abstract class BaseRpcController : RpcController
{
    mixin ActivatedMixin!();
}


/**
 * Базовый класс rpc контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
abstract class GenericRpcController(CType, IType) : BaseRpcController
{
    static assert(is(IType == interface),
            IType.stringof ~ " is not interface");

    static assert(is(CType == class),
            CType.stringof ~ " is not class");

    static assert(hasUDA!(IType, Controller),
            IType.stringof ~ " is not marked with a Controller");

    alias Handlers = GetRpcControllerMethods!IType;

    static assert(Handlers.length, "The controller must contain handlers");


    void registerHandlers(RegisterHandler hdl)
    {
        CType controller = cast(CType)this;
        foreach(Member; Handlers)
        {
            enum udas = getUDAs!(Member, Method);
            enum fName = __traits(identifier, Member);
            auto HDL = GenerateHandlerFromMethod!(
                    __traits(getMember, controller, fName))(
                    &__traits(getMember, controller, fName));
            hdl(FullMethodName!(IType, udas[0].method), HDL);
        }
    }


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
 * Базовая фабрика для RPC контроллеров
 * Params:
 * CType = Тип контроллера
 */
abstract class BaseRpcControllerFactory(string N)
    : ComponentFactory!RpcController, InitializingFactory!(RpcController), Named
{
    mixin NamedMixin!N;


    RpcController initializeComponent(RpcController component, Properties config)
    {
        component.enabled = config.getOrElse!bool("enabled", false);
        return component;
    }
}


private:


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


/**
 * Генерация обработчика на основе функции
 */
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

