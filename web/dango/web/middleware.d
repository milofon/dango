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
    import vibe.http.server : HTTPServerRequest, HTTPServerResponse, HTTPMethod,
            HTTPServerRequestDelegate;
    import uniconf.core : Config;

    import dango.web.controller : Chain;
}

private
{
    import vibe.http.server : HTTPServerRequestHandler;

    import dango.system.container;
}


/**
 * Функция регистрации обработчика
 */
alias RegisterHandlerCallback = void delegate(HTTPMethod, string,
        HTTPServerRequestDelegate);


/**
 * Интерфейс для Middleware HTTP
 * Позволяет производить предобработку входязих запросов
 */
interface WebMiddleware : ActivatedComponent
{
    void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res,
            HTTPServerRequestDelegate next) @safe;

    /**
     * Регистрация цепочек маршрутов middleware
     * На каждый обработчик формируется вызов dg
     * Params:
     * dg = Функция регистрации цепочки
     */
    void registerHandlers(HTTPMethod method, string path, RegisterHandlerCallback dg);
}



version (unittest)
{
    class TestMiddleware : BaseWebMiddleware
    {
        bool running = false;

        void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res,
                HTTPServerRequestDelegate next) @safe
        {
            running = true;
            next(req, res);
        }

        override void registerHandlers(HTTPMethod method, string path,
                RegisterHandlerCallback dg) {}
    }
}



@system unittest
{
    import vibe.http.server;
    import vibe.inet.url;

    auto req = createTestHTTPServerRequest(URL("http://localhost/"));
    auto res = createTestHTTPServerResponse();

    auto mdl = new TestMiddleware();
    bool running = false;
    void testDelegate (scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
    {
        running = true;
    }
    mdl.handleRequest(req, res, &testDelegate);
    assert (running);
}


/**
 * Базовый класс Middleware
 */
abstract class BaseWebMiddleware : WebMiddleware
{
    mixin ActivatedComponentMixin!();


    void registerHandlers(HTTPMethod method, string path, RegisterHandlerCallback dg) {}
}



alias MiddlewareComponentFactory = ComponentFactory!(WebMiddleware, Config);


/**
 * Базовая фабрика для web контроллеров
 */
abstract class WebMiddlewareFactory : MiddlewareComponentFactory
{
    BaseWebMiddleware createMiddleware(Config config);


    WebMiddleware createComponent(Config config)
    {
        auto ret = createMiddleware(config);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
}


/**
 * Регистрация компонента Middleware
 */
void registerMiddleware(M : WebMiddleware, F : MiddlewareComponentFactory, string N)(
        ApplicationContainer container)
{
    container.registerNamedComponent!(M, N, F);
}


/**
 * Регистрация компонента Middleware
 */
void registerMiddleware(M : WebMiddleware, string N)(ApplicationContainer container)
{
    class DefaultWebMiddlewareFactory : WebMiddlewareFactory
    {
        override BaseWebMiddleware createMiddleware(Config config)
        {
            return new M();
        }
    }
    auto factory = new DefaultWebMiddlewareFactory();
    container.registerNamedComponentInstance!(M, N)(factory);
}


/**
 * Проверка на наличие метода initMiddleware в классе
 */
template isInitializedMiddleware(MType, IType, alias Member)
{
    import std.meta : Alias;
    import std.traits : hasMember, Parameters, ReturnType;

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

