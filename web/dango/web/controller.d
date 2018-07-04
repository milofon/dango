/**
 * Модуль общих абстракций контроллера web приложения
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-27
 */

module dango.web.controller;

public
{
    import dango.web.middleware : WebMiddleware;

    import vibe.http.server : HTTPMethod, HTTPServerRequestHandler,
            HTTPServerRequestDelegate, HTTPServerRequest, HTTPServerResponse;
}

private
{
    import dango.system.component;

    import dango.web.middleware;
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
struct Handler
{
    string path;
    HTTPMethod method = HTTPMethod.GET;
}


/**
 * Интерфейс цепочки обработки запроса
 */
interface Chain : HTTPServerRequestHandler
{
    /**
     * Возврщает HTTPMethod
     */
    HTTPMethod method() @property;

    /**
     * Возврщает uri
     */
    string path() @property;

    /**
     * Активирует указанный middleware для текущего обработчика
     * Params:
     * mdw = middleware
     */
    void attachMiddleware(WebMiddleware mdw);
}


/**
 * Базовый класс для цепочки обработки запроса
 */
abstract class BaseChain : Chain
{
    private
    {
        WebMiddleware _headMiddleware;
    }


    this(HTTPServerRequestDelegate memberHandler)
    {
        pushMiddleware(new class BaseWebMiddleware {
            void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
            {
                memberHandler(req, res);
            }
        });
    }


    final void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        _headMiddleware.handleRequest(req, res);
    }


protected:


    void pushMiddleware(WebMiddleware next)
    {
        if (_headMiddleware is null)
            _headMiddleware = next;
        else
        {
            next.setNext(_headMiddleware);
            _headMiddleware = next;
        }
    }
}


/**
 * Функция регистрации цепочки оработки запроса
 */
alias ChainRegister = void delegate(Chain chain);


/**
 * Интерфейс для контроллера
 */
interface WebController : Activated
{
    /**
     * Регистрация цепочек маршрутов контроллера
     * На каждый обработчик формируется вызов dg
     * Params:
     * dg = Функция регистрации цепочки
     */
    void registerChains(ChainRegister dg);
}


/**
 * Базовый класс web контроллера
 * Params:
 */
abstract class BaseWebController : WebController
{
    private bool _enabled;


    bool enabled() @property
    {
        return _enabled;
    }


    void enabled(bool val) @property
    {
        this._enabled = val;
    }
}


/**
 * Базовый класс web контроллера с возможностью именования
 * Params:
 * N = Имя контроллера
 */
abstract class NamedBaseWebController(string N) : BaseWebController, Named
{
    enum NAME = N;


    string name() @property
    {
        return NAME;
    }
}


/**
 * Базовая фабрика для web контроллеров
 * Params:
 * CType = Тип контроллера
 */
class BaseWebControllerFactory(CType : WebController) : AutowireComponentFactory!(
        WebController, CType)
{
    this(ApplicationContainer container)
    {
        super(container);
    }


    override CType create(Properties config)
    {
        auto ret = new CType();
        container.autowire(ret);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
}

