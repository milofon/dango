/**
 * Модуль реализации Middleware авторизации BaseAuth
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-21
 */

module dango.service.transport.middleware.baseauth;

private
{
    import std.uni : toUpper;
    import std.string : strip;
    import std.format : fmt = format;

    import vibe.http.auth.basic_auth;

    import dango.system.properties : getOrEnforce;

    import dango.service.transport.http;
}



class BaseAuthHTTPMiddleware : BaseHTTPMiddleware!"BASEAUTH"
{
    private
    {
        string _username;
        string _password;
        string _realm;
    }


    override void middlewareConfigure(Properties config)
    {
        _username = config.getOrEnforce!string("username",
                "Not defined username parameter").strip;
        _password = config.getOrEnforce!string("password",
                "Not defined password parameter").strip;
        _realm = config.getOrElse!string("realm", "");
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        if (!checkBasicAuth(req, &passwordCheck))
        {
            res.headers["WWW-Authenticate"] = fmt!"Basic realm=\"%s\""(_realm);
            res.writeBody("Need authentication", 401);
            return;
        }
        nextRun(req, res);
    }


private:


    bool passwordCheck(string user, string passwd) @safe
    {
        return user.strip == _username && passwd.strip == _password;
    }
}

