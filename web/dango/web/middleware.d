/**
 * Модуль общих абстракций middleware web приложения
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-03
 */

module dango.web.middleware;

public
{
    import vibe.http.server : HTTPServerRequest, HTTPServerResponse, HTTPMethod;

    import dango.web.controller : Chain;
}

private
{
    import std.traits;
    import std.meta : Alias;

    import proped : Properties;
    import vibe.http.server : HTTPServerRequestDelegate, HTTPServerRequestHandler;

    import dango.system.container;
}



alias RegisterHandlerCallback = void delegate(
        HTTPMethod, string, HTTPServerRequestDelegate);


/**
 * Интерфейс для Middleware HTTP
 * Позволяет производить предобработку входязих запросов
 */
interface WebMiddleware : ActivatedComponent, HTTPServerRequestHandler
{
    /**
     * Установка след. елемента в цепочке
     */
    WebMiddleware setNext(WebMiddleware);

    /**
     * Передача управления в след. цепочку
     */
    void next(HTTPServerRequest req, HTTPServerResponse res) @safe;

    /**
     * Регистрация дополнительных обработчиков
     * Middleware может добавлять свои обработчики в роутер
     */
    void registerAdditionalHandlers(RegisterHandlerCallback cb);
}


/**
 * Базовый класс Middleware
 */
abstract class BaseWebMiddleware : WebMiddleware
{
    mixin ActivatedComponentMixin!();

    private
    {
        WebMiddleware _next;
    }


    WebMiddleware setNext(WebMiddleware next)
    {
        _next = next;
        return next;
    }


    void next(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        if (_next !is null)
            _next.handleRequest(req, res);
    }


    void registerAdditionalHandlers(RegisterHandlerCallback cb) {}
}


/**
 * Базовый именованный класс Middleware
 */
abstract class NamedWebMiddleware(string N) : BaseWebMiddleware, NamedComponent
{
    mixin NamedComponentMixin!N;
}



alias MiddlewareFactory = ComponentFactory!(WebMiddleware, Properties, Chain);


/**
 * Базовая фабрика для web контроллеров
 */
abstract class BaseWebMiddlewareFactory : MiddlewareFactory
{
    WebMiddleware createMiddleware(Properties config, Chain chain);


    WebMiddleware createComponent(Properties config, Chain chain)
    {
        auto ret = createMiddleware(config, chain);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
}


/**
 * Урощенная фабрика middleware
 */
class SimpleWebMiddlewareFactory(M : BaseWebMiddleware) : BaseWebMiddlewareFactory
{
    WebMiddleware createMiddleware(Properties config, Chain chain)
    {
        return new M();
    }
}


/**
 * Регистрация компонента Middleware
 */
void registerMiddleware(F : MiddlewareFactory, M : WebMiddleware)(
        ApplicationContainer container)
{
    container.registerFactory!(F, M);
}


/**
 * Регистрация компонента Middleware
 */
void registerMiddleware(M : WebMiddleware)(ApplicationContainer container)
{
    container.registerMiddleware!(SimpleWebMiddlewareFactory!M, M);
}


/**
 * Проверка на наличие метода initMiddleware в классе
 */
template isInitializedMiddleware(MType, IType, alias Member)
{
    enum __existsMethod = hasMember!(MType, "initMiddleware");
    static if (__existsMethod)
    {
        alias __initMiddleware = Alias!(__traits(getMember, MType, "initMiddleware"));
        alias __IM = __initMiddleware!(IType, Member);
        static assert(is(ReturnType!__IM == void),
                "initMiddleware must return void");

        alias __P = Parameters!__IM;
        static assert(__P.length == 0, "initMiddleware must no accept parameters");
    }

    enum isInitializedMiddleware = __existsMethod;
}

