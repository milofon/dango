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
 * Базовый класс web контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
abstract class GenericWebController(CType, IType) : BaseWebController, IType
{
    static assert(is(IType == interface),
            IType.stringof ~ " is not interface");

    static assert(is(CType == class),
            CType.stringof ~ " is not class");

    static assert(hasUDA!(IType, Controller),
            IType.stringof ~ " is not marked with a Controller");

    alias Handlers = GetWebControllerHandlers!IType;

    static assert(Handlers.length, "The controller must contain handlers");

    static if (Handlers.length)
        alias HandlerType = typeof(toDelegate(&Handlers[0]));

    private template __isHandler(alias T)
    {
        enum __isHandler = is(typeof(toDelegate(&T)) == HandlerType);
    }

    static assert(allSatisfy!(__isHandler, Handlers),
            "Handlers must meet the '" ~ HandlerType.stringof ~ "'");

    private enum __existsCreateHandler = hasMember!(CType, "createHandler");
    static assert(__existsCreateHandler, CType.stringof
            ~ " must contain the function "
            ~ "'HTTPServerRequestDelegate createHandler(HandlerType, alias Member)"
            ~ "(HandlerType hdl)'");

    static if (__existsCreateHandler) private
    {
        alias __createHandler = Alias!(__traits(getMember, CType, "createHandler"));
        alias __CH = __createHandler!(HandlerType, Handlers[0]);

        static assert(is(ReturnType!__CH == HTTPServerRequestDelegate),
                "createHandler must return HTTPServerRequestDelegate");

        alias __P = Parameters!__CH;
        static assert(__P.length == 1 && is(__P[0] == HandlerType),
                "createHandler must accept '" ~ HandlerType.stringof ~ "'");
    }


    void registerChains(ChainRegister dg)
    {
        CType controller = cast(CType)this;
        foreach(Member; Handlers)
        {
            enum udas = getUDAs!(Member, Handler);
            enum fName = __traits(identifier, Member);
            auto HDL = &__traits(getMember, controller, fName);
            dg(new ChainHandler!(CType, IType, Member)(controller, udas[0], HDL));
        }
    }
}


/**
 * Цепочка обработки запроса
 * Params:
 * С      = Тип контроллера
 * Member = Функция обработчик
 */
class ChainHandler(CType, IType, alias Member) : BaseChain
{
    alias MemberType = typeof(toDelegate(&Member));

    private
    {
        Handler _udaHandler;
        CType _controller;
    }


    this(CType controller, Handler uda, MemberType hdl)
    {
        this._udaHandler = uda;
        this._controller = controller;
        super(controller.createHandler!(MemberType, Member)(hdl));
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

