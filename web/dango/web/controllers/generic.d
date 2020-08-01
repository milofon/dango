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
    import std.traits : hasUDA, getUDAs, isCallable, TemplateArgsOf, Parameters;
    import std.meta;

    import bolts : FilterMembersOf, protectionLevel, ProtectionLevel;
    import dango.web.server : joinInetPath;
}


/**
 * Аннотация для обозначение объекта контроллера
 * Params:
 *
 * prefix = Префикс для всех путей
 */
struct Controller
{
    string prefix;
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
 * Базовый класс web контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
class GenericWebController(IType) : IType, WebController
    if (is(IType == class) && hasUDA!(IType, Controller))
{
    static if (__traits(compiles, __traits(getOverloads, IType, "__ctor")))
    {
        static foreach(ctor ; __traits(getOverloads, IType, "__ctor"))
        {
            this(Parameters!ctor args)
            {
                super(args);
            }
        }
    }

    /**
     * Регистрация цепочек маршрутов контроллера
     */
    void registerChains(RegisterChainCallback dg) @safe
    {
        alias Handlers = GetWebControllerHandlers!IType;
        static assert(Handlers.length, "The controller must contain handlers");

        foreach(MemberName; Handlers)
        {
            alias Member = Alias!(__traits(getMember, IType, MemberName));
            enum hdlUDA = getUDAs!(Member, Handler)[0];
            auto HDL = &__traits(getMember, this, MemberName);
            alias MemberType = typeof(toDelegate(&Member));
            dg(hdlUDA.method, getFullPath(hdlUDA.path), new Chain(HDL));
        }
    }


    private string getFullPath(string path)
    {
        enum udas = getUDAs!(IType, Controller);
        static if (udas.length > 0)
            return joinInetPath(udas[0].prefix, path);
        else
            return path;
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

