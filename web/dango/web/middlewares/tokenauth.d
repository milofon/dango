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
    import proped : Properties;

    import dango.system.properties : getOrEnforce;
    import dango.web.middleware;
}


/**
 * Middleware позволяет реализовать авторизацию по токену
 */
class TokenAuthWebMiddleware : NamedWebMiddleware!("TOKENAUTH")
{
    private string _token;


    this(string token)
    {
        this._token = token;
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
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



class TokenAuthWebMiddlewareFactory : BaseWebMiddlewareFactory
{
    override WebMiddleware createMiddleware(Properties config, Chain chain)
    {
        string token = config.getOrEnforce!string("token",
                "Token API is not defined");
        return new TokenAuthWebMiddleware(token);
    }
}

