/**
 * Модуль реализации Middleware авторизации BaseAuth
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-30
 */

module dango.web.middlewares.baseauth;

private
{
    import std.string : strip;
    import std.format : fmt = format;

    import vibe.http.auth.basic_auth;

    import dango.system.properties : getOrEnforce;
    import dango.web.middleware;
}


/**
 * Middleware позволяет реализовать аутентификацию baseauth
 */
class BaseAuthWebMiddleware : WebMiddleware
{
    private
    {
        string _username;
        string _password;
        string _realm;
    }

    /**
     * Main constructor
     */
    this(string username, string password, string realm) @safe
    {
        this._username = username;
        this._password = password;
        this._realm = realm;
    }

    /**
     * Обработка запроса
     */
    void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res,
            HTTPServerRequestDelegate next) @safe
    {
        if (!checkBasicAuth(req, &passwordCheck))
        {
            res.headers["WWW-Authenticate"] = fmt!"Basic realm=\"%s\""(_realm);
            res.writeBody("Need authentication", 401);
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


private:


    bool passwordCheck(string user, string passwd) @safe
    {
        return user.strip == _username && passwd.strip == _password;
    }
}


/**
 * Фабрика Middleware baseauth
 */
class BaseAuthWebMiddlewareFactory : WebMiddlewareFactory
{
    WebMiddleware createComponent(DependencyContainer cont, UniConf config) @safe
    {
        string username = config.getOrEnforce!string("username",
                "Not defined username parameter").strip;
        string password = config.getOrEnforce!string("password",
                "Not defined password parameter").strip;
        string realm = config.getOrElse!string("realm", "");

        return new BaseAuthWebMiddleware(username, password, realm);
    }
}

