/**
 * Модуль реализации Middleware авторизации BaseAuth
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-03
 */

module dango.web.middlewares.baseauth;

private
{
    import std.uni : toUpper;
    import std.string : strip;
    import std.format : fmt = format;

    import vibe.http.auth.basic_auth;
    import proped : Properties;

    import dango.system.properties : getOrEnforce;
    import dango.system.component;
    import dango.web.middleware;
}



class BaseAuthWebMiddleware : NamedBaseWebMiddleware!("BASEAUTH")
{
    private
    {
        string _username;
        string _password;
        string _realm;
    }


    this(string username, string password, string realm)
    {
        this._username = username;
        this._password = password;
        this._realm = realm;
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        if (!checkBasicAuth(req, &passwordCheck))
        {
            res.headers["WWW-Authenticate"] = fmt!"Basic realm=\"%s\""(_realm);
            res.writeBody("Need authentication", 401);
            return;
        }
        next(req, res);
    }


private:


    bool passwordCheck(string user, string passwd) @safe
    {
        return user.strip == _username && passwd.strip == _password;
    }
}



class BaseAuthWebMiddlewareFactory : AutowireComponentFactory!(WebMiddleware,
        BaseAuthWebMiddleware)
{
    this(ApplicationContainer container)
    {
        super(container);
    }


    override BaseAuthWebMiddleware create(Properties config)
    {
        string username = config.getOrEnforce!string("username",
                "Not defined username parameter").strip;
        string password = config.getOrEnforce!string("password",
                "Not defined password parameter").strip;
        string realm = config.getOrElse!string("realm", "");

        auto ret = new BaseAuthWebMiddleware(username, password, realm);
        container.autowire(ret);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }
}

