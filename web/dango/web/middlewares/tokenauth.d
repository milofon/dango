/**
 * Модуль реализации Middleware аутентификации по токену
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-27
 */

module dango.web.middlewares.tokenauth;

private
{
    import dango.web.middleware;
}


/**
 * Middleware позволяет реализовать авторизацию по токену
 */
class TokenAuthWebMiddleware : BaseWebMiddleware
{
    private string _token;


    this(string token)
    {
        this._token = token;
    }


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
}


/**
 * Фабрика Middleware tokenauth
 */
class TokenAuthWebMiddlewareFactory : WebMiddlewareFactory
{
    override BaseWebMiddleware createMiddleware(Config config)
    {
        string token = config.getOrEnforce!string("token",
                "Token API is not defined");
        return new TokenAuthWebMiddleware(token);
    }
}

