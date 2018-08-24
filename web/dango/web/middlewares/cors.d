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
    import std.algorithm.iteration : map, splitter, filter;
    import std.algorithm.searching : canFind;
    import std.format : fmt = format;
    import std.array : array, join;
    import std.uni : toLower, toUpper;
    import std.conv : to;

    import vibe.http.server : HTTPMethod;
    import vibe.inet.url : URL;

    import proped : Properties;
    import dango.system.exception : configEnforce, ConfigException;
    import dango.system.properties : getOrEnforce;

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
        Chain _chain;
        ulong _maxAge;
    }


    this(Chain chain, AllowChecker oCk, AllowChecker mCk, AllowChecker hCk, long maxAge)
    {
        this._originChecker = oCk;
        this._methodChecker = mCk;
        this._headerChecker = hCk;
        this._maxAge = maxAge;
        this._chain = chain;
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        auto origin = "Origin" in req.headers;

        if (origin && _originChecker(*origin))
        {
            res.headers["Access-Control-Allow-Origin"] = *origin;
            res.headers["Access-Control-Allow-Credentials"] = "true";
        }

        next(req, res);
    }


    override void registerAdditionalHandlers(RegisterHandlerCallback dg)
    {
        dg(HTTPMethod.OPTIONS, _chain.path, &handleOptionsRequest);
    }


private:


    void handleOptionsRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
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



class CorsWebMiddlewareFactory : BaseWebMiddlewareFactory
{
    override WebMiddleware createMiddleware(Properties config, Chain chain)
    {
        AllowChecker oCk = createOriginChecker(config.getArray("origin"));
        AllowChecker mCk = createMethodChecker(config.getArray("method"));
        AllowChecker hCk = createHeaderChecker(config.getArray("header"));
        long maxAge = config.getOrElse!long("maxAge", 300);
        return new CorsWebMiddleware(chain, oCk, mCk, hCk, maxAge);
    }


private:


    AllowChecker createOriginChecker(Properties[] origins)
    {
        import std.regex;

        enum replaceRx = ctRegex!(`\\\*`);
        Regex!char[] regs;

        foreach (Properties origin; origins)
        {
            auto origStr = origin.get!string();
            configEnforce(!origStr.isNull, "Origin must be a string");

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


    AllowChecker createMethodChecker(Properties[] methodProps)
    {
        string[] methods;

        foreach (Properties mp; methodProps)
        {
            auto m = mp.get!string();
            configEnforce(!m.isNull, "Method must be a string");
            methods ~= m.get.toUpper;
        }

        return (string val)
        {
            return methods.canFind(val.toUpper);
        };
    }


    AllowChecker createHeaderChecker(Properties[] headerProps)
    {
        string[] headers;

        foreach (Properties hp; headerProps)
        {
            auto h = hp.get!string();
            configEnforce(!h.isNull, "Header must be a string");
            headers ~= h.get.toLower;
        }

        return (string val)
        {
            return headers.canFind(val.toLower);
        };
    }
}

