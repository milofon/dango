/**
 * Модуль общих абстракций middleware web приложения
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-30
 */

module dango.web.middleware;

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

    import dango.inject : ComponentFactory;
}


/// Функция регистрации обработчика
alias RegisterHandlerCallback = void delegate(HTTPMethod, string,
        HTTPServerRequestDelegate) @safe;

/// Фабрика web middleware
alias WebMiddlewareFactory = ComponentFactory!(WebMiddleware, DependencyContainer, UniConf);


/**
 * Интерфейс для Middleware HTTP
 * Позволяет производить предобработку входязих запросов
 */
interface WebMiddleware
{
    /**
     * Обработка запроса
     */
    void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res,
            HTTPServerRequestDelegate next) @safe;

    /**
     * Регистрация цепочек маршрутов middleware
     * На каждый обработчик формируется вызов dg
     * Params:
     * dg = Функция регистрации цепочки
     */
    void registerHandlers(HTTPMethod method, string path, RegisterHandlerCallback dg) @safe;
}

