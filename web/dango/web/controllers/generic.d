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
    // import vibe.internal.meta.traits : RecursiveFunctionAttributes;
    import dango.web.controller;
}

private
{
    import std.functional : toDelegate;
    import std.traits : hasUDA, getUDAs, isCallable, TemplateArgsOf;
    import std.meta;

    import dango.system.traits;
    import dango.web.middleware : isInitializedMiddleware;
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



@system unittest
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
 * Аннотация позволяющая указать middleware которым
 * доступны аннотации обработчиков
 */
struct Middleware(MTypes...) {}


/**
 * Базовый класс web контроллера
 * Params:
 * CType = Объект с определенными в нем обработчиками
 */
abstract class GenericWebController(IType) : BaseWebController, IType
    if (is(IType == interface))
{
    static assert(hasUDA!(IType, Controller),
            IType.stringof ~ " is not marked with a Controller");


    void registerChains(RegisterChainCallback dg)
    {
        alias Handlers = GetWebControllerHandlers!IType;
        static assert(Handlers.length, "The controller must contain handlers");

        foreach(Member; Handlers)
        {
            enum hdlUDA = getUDAs!(Member, Handler)[0];
            enum fName = __traits(identifier, Member);
            auto HDL = &__traits(getMember, this, fName);
            alias MemberType = typeof(toDelegate(&Member));
            auto hdl = createHandler!(IType, MemberType, Member)(this, HDL);
            if (hdl !is null)
                dg(hdlUDA.method, getFullPath(hdlUDA.path),
                        new GenericChain!(IType, Member)(hdl));
        }
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

        return joinPath(this.prefix, ctrlPath);
    }


    static string joinPath(string prefix, string path)
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


private:


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
 * Функция создания обработчика
 *
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
    return assumeSafe!HandlerType(hdl);
}



class GenericChain(IType, alias Member) : Chain
{
    this(Handler)(Handler handler)
    {
        super(handler);
    }


    override void attachMiddleware(WebMiddleware middleware)
    {
        foreach (mTypes; getUDAs!(IType, Middleware))
        {
            foreach(mType; TemplateArgsOf!mTypes)
            {
                static if (isInitializedMiddleware!(mType, IType, Member))
                    if (mType m = cast(mType)middleware)
                        m.initMiddleware!(IType, Member)();
            }
        }
        super.attachMiddleware(middleware);
    }
}

