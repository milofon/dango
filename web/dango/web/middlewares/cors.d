/**
 * Модуль реализации Middleware CORS
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-03
 */

module dango.web.middlewares.cors;

private
{
    import std.algorithm.iteration : splitter, filter;
    import std.algorithm.searching : canFind;
    import std.array : array, join;
    import std.uni : toLower, toUpper;
    import std.conv : to;

    import dango.system.properties : enforceConfig;
    import dango.web.middleware;
}


alias AllowChecker = bool delegate(string val) @safe;


/**
 * Middleware позволяет реализовать CORS доступ
 */
class CorsWebMiddleware : BaseWebMiddleware
{
    private
    {
        AllowChecker _originChecker;
        AllowChecker _methodChecker;
        AllowChecker _headerChecker;
        ulong _maxAge;
    }


    this(AllowChecker oCk, AllowChecker mCk, AllowChecker hCk, long maxAge)
    {
        this._originChecker = oCk;
        this._methodChecker = mCk;
        this._headerChecker = hCk;
        this._maxAge = maxAge;
    }


    void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res,
            HTTPServerRequestDelegate next) @safe
    {
        auto origin = "Origin" in req.headers;

        if (origin && _originChecker(*origin))
        {
            res.headers["Access-Control-Allow-Origin"] = *origin;
            res.headers["Access-Control-Allow-Credentials"] = "true";
        }

        next(req, res);
    }


    override void registerHandlers(HTTPMethod method, string path, RegisterHandlerCallback dg)
    {
        dg(HTTPMethod.OPTIONS, path, &handleOptionsRequest);
    }


private:


    void handleOptionsRequest(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
    {
        auto origin = "Origin" in req.headers;

        if (origin && _originChecker(*origin))
        {
            res.headers["Access-Control-Allow-Origin"] = *origin;
            res.headers["Access-Control-Allow-Credentials"] = "true";

            res.headers["Access-Control-Max-Age"] = _maxAge.to!string;

            auto method = "Access-Control-Request-Method" in req.headers;
            if (method && _methodChecker(*method))
                res.headers["Access-Control-Allow-Methods"] = *method;

            if (auto headers = "Access-Control-Request-Headers" in req.headers)
            {
                auto hds = splitter(*headers, ",").filter!(h=> _headerChecker(h));
                res.headers["Access-Control-Allow-Headers"] = hds.join(",");
            }
        }

        res.writeBody("");
    }
}


/**
 * Фабрика Middleware CORS
 */
class CorsWebMiddlewareFactory : WebMiddlewareFactory
{
    override BaseWebMiddleware createMiddleware(Config config)
    {
        AllowChecker oCk = createOriginChecker(config.getArray("origin"));
        AllowChecker mCk = createMethodChecker(config.getArray("method"));
        AllowChecker hCk = createHeaderChecker(config.getArray("header"));
        long maxAge = config.getOrElse!long("maxAge", 300);
        return new CorsWebMiddleware(oCk, mCk, hCk, maxAge);
    }


private:


    AllowChecker createOriginChecker(Config[] origins)
    {
        import std.regex;

        enum replaceRx = ctRegex!(`\\\*`);
        Regex!char[] regs;

        foreach (Config origin; origins)
        {
            auto origStr = origin.get!string();
            enforceConfig(!origStr.isNull, "Origin must be a string");

            string escapeOrig = origStr.get.escaper.array.to!string;
            string repOrig = escapeOrig.replaceAll(replaceRx, "(.*?)");
            string regexOrig = "^" ~ repOrig ~ "$";

            regs ~= regex(regexOrig);
        }

        return (string val)
        {
            foreach (re; regs)
            {
                if (!match(val, re).empty)
                    return true;
            }
            return false;
        };
    }


    AllowChecker createMethodChecker(Config[] methodProps)
    {
        string[] methods;

        foreach (Config mp; methodProps)
        {
            auto m = mp.get!string();
            enforceConfig(!m.isNull, "Method must be a string");
            methods ~= m.get.toUpper;
        }

        return (string val)
        {
            return methods.canFind(val.toUpper);
        };
    }


    AllowChecker createHeaderChecker(Config[] headerProps)
    {
        string[] headers;

        foreach (Config hp; headerProps)
        {
            auto h = hp.get!string();
            enforceConfig(!h.isNull, "Header must be a string");
            headers ~= h.get.toLower;
        }

        return (string val)
        {
            return headers.canFind(val.toLower);
        };
    }
}

