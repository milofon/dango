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
    import proped : Properties;

    import vibe.http.server : HTTPMethod, HTTPServerRequestHandler,
            HTTPServerRequestDelegate, HTTPServerRequest, HTTPServerResponse;

    import dango.web.middleware : WebMiddleware;

    import dango.web.controllers.generic;
}

private
{
    import dango.system.container;

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
    mixin ActivatedMixin!();
}


/**
 * Базовая фабрика для web контроллеров
 * Params:
 * CType = Тип контроллера
 */
abstract class BaseWebControllerFactory(string N)
    : ComponentFactory!(WebController), InitializingFactory!(WebController), Named
{
    mixin NamedMixin!N;


    WebController initializeComponent(WebController component, Properties config)
    {
        component.enabled = config.getOrElse!bool("enabled", false);
        return component;
    }
}

