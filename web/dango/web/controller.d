/**
 * Модуль общих абстракций контроллера web приложения
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-30
 */

module dango.web.controller;

public
{
    import uniconf.core : UniConf;
    import vibe.http.server : HTTPServerRequest, HTTPServerResponse,
            HTTPServerRequestDelegate, HTTPMethod;
    import dango.inject : DependencyContainer;
}

private
{
    import vibe.http.server;
    import vibe.http.router : URLRouter;
    alias isValidHandler = URLRouter.isValidHandler;
    alias handlerDelegate = URLRouter.handlerDelegate;

    import dango.inject : ComponentFactory;
    import dango.web.middleware : WebMiddleware;
}


/**
 * Функция регистрации цепочки оработки запроса
 */
alias RegisterChainCallback = void delegate(HTTPMethod, string, Chain) @safe;


/// Фабрика web контроллера
alias WebControllerFactory = ComponentFactory!(WebController, DependencyContainer, UniConf);


/**
 * Интерфейс для контроллера
 */
interface WebController
{
    /**
     * Регистрация цепочек маршрутов контроллера
     * На каждый обработчик формируется вызов dg
     * Params:
     * dg = Функция регистрации цепочки
     */
    void registerChains(RegisterChainCallback dg) @safe;
}


/**
 * Декоратор обработчика запросов добавляющий функционал цепочки вызовов
 * На основе обработчика формируется цепочка обработки вызова
 */
class Chain : HTTPServerRequestHandler
{
    private HTTPServerRequestDelegate _head;

    /**
     * Main contructor
     */
    this(Handler)(Handler handler) @safe
        if (isValidHandler!Handler)
    {
        _head = handlerDelegate(handler);
    }

    /**
     * Прикреаляет Middleware для текущего обработчика
     * Params:
     * handler = Обработчик
     */
    void attachMiddleware(WebMiddleware middleware) @safe
    {
        _head = handlerMiddleware(middleware, _head);
    }

    /**
     * Обработка запроса
     */
    final void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
    {
        _head(req, res);
    }

    /**
     * Создание обработчика на основе WebMiddleware
     */
    private HTTPServerRequestDelegateS handlerMiddleware(Handler)(WebMiddleware middleware,
            Handler next) if (isValidHandler!Handler)
    {
        return (scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
        {
            middleware.handleRequest(req, res, handlerDelegate(next));
        };
    }
}

