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
    import vibe.http.server : HTTPMethod, HTTPServerRequestHandler,
            HTTPServerRequestDelegate, HTTPServerRequest, HTTPServerResponse;

    import uniconf.core : Config;

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
 * На основе обработчика формируется цепочка обработки вызова
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


    final void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        _headMiddleware.handleRequest(req, res);
    }


protected:


    void registerChainHandler(HTTPServerRequestDelegate dg)
    {
        pushMiddleware(new class BaseWebMiddleware {
            void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
            {
                dg(req, res);
            }
        });
    }


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
alias ChainRegisterCallback = void delegate(Chain chain);


/**
 * Интерфейс для контроллера
 */
interface WebController : ActivatedComponent
{
    /**
     * Регистрация цепочек маршрутов контроллера
     * На каждый обработчик формируется вызов dg
     * Params:
     * dg = Функция регистрации цепочки
     */
    void registerChains(ChainRegisterCallback dg);

    /**
     * Возвращает префикс контроллера
     */
    string prefix() @property;
}


/**
 * Базовый класс web контроллера
 */
abstract class BaseWebController : WebController
{
    mixin ActivatedComponentMixin!();

    private string _prefix;


    string prefix() @property
    {
        return _prefix;
    }
}



alias ControllerFactory = ComponentFactory!(WebController, Config);


/**
 * Базовая фабрика для web контроллеров
 * Params:
 * CType = Тип контроллера
 */
abstract class BaseWebControllerFactory : ControllerFactory
{
    BaseWebController createController(Config config);


    WebController createComponent(Config config)
    {
        auto ret = createController(config);
        ret.enabled = config.getOrElse!bool("enabled", false);
        ret._prefix = config.getOrElse!string("prefix", "");
        return ret;
    }
}


/**
 * Урощенная фабрика контроллера
 */
class SimpleWebControllerFactory(C : BaseWebController) : BaseWebControllerFactory
{
    override BaseWebController createController(Config config)
    {
        return createSimpleComponent!C(config);
    }
}


/**
 * Регистрация компонента Middleware
 */
void registerController(F : ControllerFactory, C : WebController, string N)(
        ApplicationContainer container)
{
    container.registerNamedFactory!(F, C, N);
}


/**
 * Регистрация компонента Middleware
 */
void registerController(C : WebController, string N)(ApplicationContainer container)
{
    container.registerController!(SimpleWebControllerFactory!(C), C, N);
}

