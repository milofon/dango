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
            HTTPServerRequestDelegate, HTTPServerRequestDelegateS,
            HTTPServerRequest, HTTPServerResponse;

    import uniconf.core : Config;

    import dango.web.middleware : WebMiddleware;
}

private
{
    import poodinis : Registration;

    import vibe.http.router : URLRouter;
    alias isValidHandler = URLRouter.isValidHandler;
    alias handlerDelegate = URLRouter.handlerDelegate;

    import dango.system.inject;
}


/**
 * Декоратор обработчика запросов добавляющий функционал цепочки вызовов
 * На основе обработчика формируется цепочка обработки вызова
 */
class Chain : HTTPServerRequestHandler
{
    private HTTPServerRequestDelegate _head;


    this(Handler)(Handler handler)
        if (isValidHandler!Handler)
    {
        _head = handlerDelegate(handler);
    }


    /**
     * Прикреаляет Middleware для текущего обработчика
     * Params:
     * handler = Обработчик
     */
    void attachMiddleware(WebMiddleware middleware)
    {
        _head = handlerMiddleware(middleware, _head);
    }


    final void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        _head(req, res);
    }
}



@system unittest
{
    bool running = false;
    void testDelegate (scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
    {
        running = true;
    }

    import dango.web.middleware : TestMiddleware;
    import vibe.http.server;
    import vibe.inet.url;

    auto mdl = new TestMiddleware();
    auto req = createTestHTTPServerRequest(URL("http://localhost/"));
    auto res = createTestHTTPServerResponse();

    auto ch = new Chain(&testDelegate);
    ch.attachMiddleware(mdl);
    ch.handleRequest(req, res);

    assert (mdl.running);
    assert (running);
}


/**
 * Функция регистрации цепочки оработки запроса
 */
alias RegisterChainCallback = void delegate(HTTPMethod, string, Chain);


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
    void registerChains(RegisterChainCallback dg);

    /**
     * Возвращает префикс контроллера
     */
    string prefix() @property;
}


/**
 * Базовая реализация для контроллера
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



alias ControllerComponentFactory = ComponentFactory!(WebController, Config);


/**
 * Базовая фабрика для web контроллеров
 * Params:
 * CType = Тип контроллера
 */
abstract class WebControllerFactory : ControllerComponentFactory
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
 * Регистрация компонента Middleware
 */
Registration registerController(C : WebController, F : WebControllerFactory, string N)(
        ApplicationContainer container)
{
    return container.registerNamedFactory!(C, N, F);
}


/**
 * Регистрация компонента Middleware
 */
Registration registerController(C : WebController, string N)(ApplicationContainer container)
{
    class DefaultWebControllerFactory : WebControllerFactory
    {
        override BaseWebController createController(Config config)
        {
            return new C();
        }
    }
    auto factory = new DefaultWebControllerFactory();
    return container.registerNamedExistingFactory!(C, N)(factory);
}


private:


/**
 * Создание обработчика на основе WebMiddleware
 */
HTTPServerRequestDelegateS handlerMiddleware(Handler)(WebMiddleware middleware,
        Handler next) if (isValidHandler!Handler)
{
    return (scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
    {
        middleware.handleRequest(req, res, handlerDelegate(next));
    };
}

