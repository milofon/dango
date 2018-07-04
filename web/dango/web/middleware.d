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
    import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
}

private
{
    import std.traits;
    import std.meta : Alias;

    import vibe.http.server : HTTPServerRequestHandler;

    import dango.system.component;
}


/**
 * Интерфейс для Middleware HTTP
 * Позволяет производить предобработку входязих запросов
 */
interface WebMiddleware : Activated, HTTPServerRequestHandler
{
    WebMiddleware setNext(WebMiddleware);


    void next(HTTPServerRequest req, HTTPServerResponse res) @safe;
}


/**
 * Базовый класс Middleware
 */
abstract class BaseWebMiddleware : WebMiddleware
{
    private
    {
        bool _enabled;
        WebMiddleware _next;
    }


    bool enabled() @property
    {
        return _enabled;
    }


    void enabled(bool val) @property
    {
        this._enabled = val;
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
}


/**
 * Базовый класс Middleware с возможность именования
 * Params:
 * N = Имя компонента
 */
abstract class NamedBaseWebMiddleware(string N) : BaseWebMiddleware, Named
{
    enum NAME = N;


    string name() @property
    {
        return NAME;
    }
}


/**
 * Базовая фабрика для web контроллеров
 */
class BaseWebMiddlewareFactory(MType : WebMiddleware) : AutowireComponentFactory!(
        WebMiddleware, MType)
{
    this(ApplicationContainer container)
    {
        super(container);
    }


    override MType create(Properties config)
    {
        auto ret = new MType();
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
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

