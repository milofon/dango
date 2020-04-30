/**
 * Модуль реализации Middleware аутентификации по токену
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-30
 */

module dango.web.middlewares.tokenauth;

private
{
    import dango.system.properties : getOrEnforce;
    import dango.web.middleware;
}


/**
 * Middleware позволяет реализовать авторизацию по токену
 */
class TokenAuthWebMiddleware : WebMiddleware
{
    private string _token;

    /**
     * Main container
     */
    this(string token) @safe
    {
        this._token = token;
    }

    /**
     * Обработка запроса
     */
    void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res,
            HTTPServerRequestDelegate next) @safe
    {
        auto token = "X-Auth-Token" in req.headers;
        if (!token || *token != _token)
        {
            res.writeBody("Need authentication", 403);
            return;
        }

        next(req, res);
    }

    /**
     * Регистрация цепочек маршрутов middleware
     */
    void registerHandlers(HTTPMethod method, string path, RegisterHandlerCallback dg) @safe
    {
        // nothing
    }
}


/**
 * Фабрика Middleware tokenauth
 */
class TokenAuthWebMiddlewareFactory : WebMiddlewareFactory
{
    WebMiddleware createComponent(DependencyContainer cont, UniConf config) @safe
    {
        string token = config.getOrEnforce!string("token",
                "Token API is not defined");
        return new TokenAuthWebMiddleware(token);
    }
}

