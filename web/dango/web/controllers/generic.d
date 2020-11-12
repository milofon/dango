/**
 * Модуль контроллера генерирующий обработчики в compile time на основе интерфейсов
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-08-01
 */

module dango.web.controllers.generic;

public
{
    import dango.web.controller;
}

private
{
    import std.functional : toDelegate;
    import std.traits;
    import std.meta;

    import bolts : FilterMembersOf, protectionLevel, ProtectionLevel;

    import dango.inject.provider : ClassProvider;
    import dango.system.logging : logError;
    import dango.web.server : joinInetPath;
}


/**
 * Аннотация для обозначение объекта контроллера
 */
struct ControllerAttribute(alias W)
{
    string prefix;
}


/**
 * Аннотация для обозначение объекта контроллера
 * Params:
 *
 * prefix = Префикс для всех путей
 */
ControllerAttribute!W Controller(alias W = defaultHandler)(string prefix = "")
{
    return ControllerAttribute!W(prefix);
}


/**
 * Аннотация для обозначения метода для обработки входящих запросов
 * Params:
 *
 * path   = Путь
 * method = Метод
 */
struct Handler(HTTPMethod M = HTTPMethod.GET)
{
    string path;
    enum method = M;
}

alias Get = Handler!(HTTPMethod.GET);
alias Post = Handler!(HTTPMethod.POST);
alias Put = Handler!(HTTPMethod.PUT);
alias Delete = Handler!(HTTPMethod.DELETE);

@("Should work Hander")
@safe unittest
{
    auto hdl = Post("/");
    assert (hdl.method == HTTPMethod.POST);

    @Post("/")
    void handler() {}
    assert (hasUDA!(handler, Handler));

    void noHandler() {}
    assert (!hasUDA!(noHandler, Handler));

    @Handler!(HTTPMethod.HEAD)("/h")
    void customHandler() {}

    enum udas = getUDAs!(customHandler, Handler);
    assert (udas.length);
    assert (udas[0].method == HTTPMethod.HEAD);
    assert (udas[0].path == "/h");
}


/**
 * Обертка над обработчиками по умочлчанию
 */
HTTPServerRequestDelegate defaultHandler(C, HType, alias M)(C controller, HType hdl) @safe
{
    return hdl;
}


/**
 * Базовый класс web контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
class GenericWebController(CType) : WebController
    if (is(CType == class))
{
    private
    {
        alias CTLs = GetControllerUDAs!CType;
        static assert(CTLs.length,
                "Class '" ~ CType.stringof ~ "' is not controller");
        enum CTL = CTLs[0];
        alias WRAP = TemplateArgsOf!(typeof(CTL))[0];
        enum __errorMsg = "The handler creation function must match '" ~
            WRAP.stringof ~ "'";
        CType _controller;
    }

    /**
     * Main constructor
     */
    this(CType controller) @safe
    {
        this._controller = controller;
    }

    /**
     * Регистрация цепочек маршрутов контроллера
     */
    void registerChains(RegisterChainCallback dg) @safe
    {
        alias Handlers = GetWebControllerHandlers!CType;
        static assert(Handlers.length, "The controller '" ~ CType.stringof
                ~ "' must contain handlers");

        foreach(MemberName; Handlers)
        {
            alias Member = Alias!(__traits(getMember, CType, MemberName));
            enum hdlUDA = getUDAs!(Member, Handler)[0];
            auto HDL = &__traits(getMember, _controller, MemberName);
            alias MemberType = typeof(toDelegate(HDL));
            enum ident = __traits(identifier, Member);

            alias __wrap = WRAP!(CType, MemberType, Member);
            static assert(is(ReturnType!__wrap == HTTPServerRequestDelegate),
                    "Handler must return HTTPServerRequestDelegate");
            alias __P = Parameters!__wrap;
            static assert(__P.length == 2, __errorMsg);
            static assert(is(__P[0] : CType), __errorMsg);
            static assert(is(__P[1] == MemberType), __errorMsg);

            auto hdl = __wrap(_controller, HDL);
            if (hdl !is null)
                dg(hdlUDA.method, getFullPath(hdlUDA.path), new Chain(hdl));
            else
                logError("Handler '%s' in controller '%s' not register",
                        MemberName, CType.stringof);
        }
    }


    private string getFullPath(string path)
    {
        static if (CTL.prefix.length > 0)
            return joinInetPath(CTL.prefix, path);
        else
            return path;
    }
}


/**
 * Фабрика для контроллера на основе кодогенерации
 */
class GenericWebControllerFactory(CType) : WebControllerFactory
    if (is(CType == class))
{
    static assert(IsGenericController!CType,
            "Class '" ~ CType.stringof ~ "' is not controller");

    /**
     * Создает новый контроллер
     */
    WebController createComponent(DependencyContainer cnt, UniConf conf) @safe
    {
        CType controller;
        auto provider = new ClassProvider!(CType, CType)(cnt);
        provider.withProvided(true, (val) @trusted {
                controller = cast(CType)(*(cast(Object*)val));
            });
        return new GenericWebController!CType(controller);
    }
}


private:


/**
 * Возвращает список обработчиков контроллера
 * Params:
 * C = Проверяемый тип
 */
template GetWebControllerHandlers(C)
{
    template IsHandler(T, string name)
    {
        alias Member = Alias!(__traits(getMember, T, name));
        static if (protectionLevel!Member == ProtectionLevel.public_)
        {
            static if (isCallable!Member && getUDAs!(Member, Handler).length)
                enum IsHandler = true;
            else
                enum IsHandler = false;
        }
        else
            enum IsHandler = false;
    }

    alias GetWebControllerHandlers = FilterMembersOf!(C, IsHandler);
}


/**
 * Проверка на тип контроллера
 */
template IsGenericController(CType)
{
    enum IsGenericController = GetControllerUDAs!CType.length > 0;
}


/**
 * Возвращает аннотации контроллера
 */
template GetControllerUDAs(CType)
{
    template IsController(alias A)
    {
        static if (!isType!A)
        {
            enum V = A; // call is function
            enum IsController = __traits(isSame,
                    TemplateOf!(typeof(V)), ControllerAttribute);
        }
        else
            enum IsController = false;
    }

    alias GetControllerUDAs = Filter!(IsController,
            __traits(getAttributes, CType));
}

