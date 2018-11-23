/**
 * Модуль контроллера генерирующий обработчики в compile time на основе интерфейсов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-04
 */

module dango.web.controllers.generic;

public
{
    import vibe.internal.meta.funcattr;
    import vibe.internal.meta.traits : RecursiveFunctionAttributes;
    import dango.web.controller;
}

private
{
    import std.functional : toDelegate;
    import std.traits;
    import std.meta;

    import dango.system.traits;
}


/**
 * Аннотация позволяющая указать middleware которым
 * доступны аннотации обработчиков
 */
struct Middleware(MTypes...) {}


/**
 * Возвращает список обработчиков контроллера
 * Params:
 * C = Проверяемый тип
 */
template GetWebControllerHandlers(C)
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
                static if (isCallable!Member && getUDAs!(Member, Handler).length)
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

    alias GetWebControllerHandlers = Get!(__traits(allMembers, C));
}


/**
 * Упроценная функция создания обработчика
 * Params:
 * IType = Тип интерфейса контроллера
 * HandlerType = Тип функции обработчика
 * Member = Функция обработчик
 * controller = Объект контроллера
 * hdl = Реализация функции обработчика
 */
HTTPServerRequestDelegate createHandler(IType, HandlerType, alias Member)(
        IType controller, HandlerType hdl)
{
    return (HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        assumeSafe!HandlerType(hdl)(req, res);
    };
}


/**
 * Базовый класс web контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
abstract class GenericWebController(IType) : BaseWebController, IType
    if (is(IType == interface))
{
    static assert(is(IType == interface),
            IType.stringof ~ " is not interface");

    static assert(hasUDA!(IType, Controller),
            IType.stringof ~ " is not marked with a Controller");

    alias Handlers = GetWebControllerHandlers!IType;

    static assert(Handlers.length, "The controller must contain handlers");


    void registerChains(ChainRegisterCallback dg)
    {
        foreach(Member; Handlers)
        {
            enum udas = getUDAs!(Member, Handler);
            enum fName = __traits(identifier, Member);
            auto HDL = &__traits(getMember, this, fName);
            alias MemberType = typeof(toDelegate(&Member));
            auto hdl= createHandler!(IType, MemberType, Member)(this, HDL);
            if (hdl !is null)
                dg(new ChainHandler!(IType, Member)(this, udas[0], hdl));
        }
    }
}


/**
 * Цепочка обработки запроса
 * Params:
 * С      = Тип контроллера
 * Member = Функция обработчик
 */
class ChainHandler(IType, alias Member) : BaseChain
{
    private
    {
        Handler _udaHandler;
        BaseWebController _controller;
    }


    this(BaseWebController controller, Handler uda, HTTPServerRequestDelegate hdl)
    {
        this._udaHandler = uda;
        this._controller = controller;
        registerChainHandler(hdl);
    }


    HTTPMethod method() @property
    {
        return _udaHandler.method;
    }


    string path() @property
    {
        return getFullPath(_udaHandler.path);
    }


    void attachMiddleware(WebMiddleware mdw)
    {
        foreach (mTypes; getUDAs!(IType, Middleware))
        {
            foreach(mType; TemplateArgsOf!mTypes)
            {
                static if (isInitializedMiddleware!(mType, IType, Member))
                    if (mType m = cast(mType)mdw)
                        m.initMiddleware!(IType, Member)();
            }
        }

        pushMiddleware(mdw);
    }


private:


    string getFullPath(string path)
    {
        import vibe.core.path : InetPath;

        enum udas = getUDAs!(IType, Controller);
        static if (udas.length > 0)
            string ctrlPath = joinPath(udas[0].prefix, path);
        else
            string ctrlPath = path;

        return joinPath(_controller.prefix, ctrlPath);
    }


    string joinPath(string prefix, string path)
    {
        import vibe.core.path : InetPath;

        auto parent = InetPath(prefix);
        auto child = InetPath(path);

        if (!parent.absolute)
            parent = InetPath("/") ~ parent;

        if (child.absolute)
        {
            auto childSegments = child.bySegment();
            childSegments.popFront();
            child = InetPath(childSegments);
        }

        if (!child.empty)
            parent ~= child;

        return parent.toString;
    }
}

