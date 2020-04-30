/**
 * Модуль реализации Middleware CORS
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-30
 */

module dango.web.middlewares.cors;

private
{
    import std.algorithm.iteration : splitter, filter;
    import std.algorithm.searching : canFind;
    import std.uni : toLower, toUpper;
    import std.array : array, join;
    import std.conv : to;

    import dango.inject : DependencyContainer;
    import dango.system.exception : enforceConfig;
    import dango.system.properties;
    import dango.web.middleware;
}


/// Проверка
alias AllowChecker = bool delegate(string val) @safe;


/**
 * Middleware позволяет реализовать CORS доступ
 */
class CORSWebMiddleware : WebMiddleware
{
    private
    {
        AllowChecker _originChecker;
        AllowChecker _methodChecker;
        AllowChecker _headerChecker;
        ulong _maxAge;
    }

    /**
     * Main constructor
     */
    this(AllowChecker oCk, AllowChecker mCk, AllowChecker hCk, long maxAge) @safe
    {
        this._originChecker = oCk;
        this._methodChecker = mCk;
        this._headerChecker = hCk;
        this._maxAge = maxAge;
    }

    /**
     * Обработка запроса
     */
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

    /**
     * Регистрация цепочек маршрутов middleware
     */
    void registerHandlers(HTTPMethod method, string path, RegisterHandlerCallback dg) @safe
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
class CORSWebMiddlewareFactory : WebMiddlewareFactory
{
    WebMiddleware createComponent(DependencyContainer cont, UniConf config) @safe
    {
        AllowChecker oCk = createOriginChecker(config.toSequence("origin"));
        AllowChecker mCk = createMethodChecker(config.toSequence("method"));
        AllowChecker hCk = createHeaderChecker(config.toSequence("header"));
        long maxAge = config.getOrElse!long("maxAge", 300);
        return new CORSWebMiddleware(oCk, mCk, hCk, maxAge);
    }


private:


    AllowChecker createOriginChecker(UniConf[] origins) @safe
    {
        import std.regex;

        enum replaceRx = ctRegex!(`\\\*`);
        Regex!char[] regs;

        foreach (UniConf origin; origins)
        {
            auto origStr = origin.opt!string();
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


    AllowChecker createMethodChecker(UniConf[] methodProps) @safe
    {
        string[] methods;

        foreach (UniConf mp; methodProps)
        {
            auto m = mp.opt!string();
            enforceConfig(!m.isNull, "Method must be a string");
            methods ~= m.get.toUpper;
        }

        return (string val)
        {
            return methods.canFind(val.toUpper);
        };
    }


    AllowChecker createHeaderChecker(UniConf[] headerProps) @safe
    {
        string[] headers;

        foreach (UniConf hp; headerProps)
        {
            auto h = hp.opt!string();
            enforceConfig(!h.isNull, "Header must be a string");
            headers ~= h.get.toLower;
        }

        return (string val)
        {
            return headers.canFind(val.toLower);
        };
    }
}

