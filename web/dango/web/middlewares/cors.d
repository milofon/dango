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
    import std.algorithm.searching : canFind;
    import std.algorithm.iteration : filter;
    import std.format : fmt = format;
    import std.array : split, join;
    import std.uni : toLower, toUpper;
    import std.conv : to;

    import vibe.http.server : HTTPMethod;
    import vibe.inet.url : URL;

    import dango.system.exception : configEnforce, ConfigException;
    import dango.system.properties : getOrEnforce;
    import dango.system.container;

    import dango.web.middleware;
}



class CorsWebMiddleware : BaseWebMiddleware
{
    private
    {
        string[] _allowOrigins;
        string[] _allowMethods;
        string[] _allowHeaders;
    }


    this(string[] origins, string[] methods, string[] headers)
    {
        this._allowOrigins = origins;
        this._allowMethods = methods;
        this._allowHeaders = headers;
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        auto origin = "Origin" in req.headers;

        // Если Origin нет в запросе или его нет
        // в разрешенных то пропускаем дальше
        if (origin is null || !isAllowedOrigin(*origin))
        {
            next(req, res);
            return;
        }

        res.headers["Access-Control-Allow-Origin"] = *origin;
        res.headers["Access-Control-Allow-Credentials"] = "true";

        if (req.method == HTTPMethod.OPTIONS)
        {
            res.headers["Access-Control-Max-Age"] = "-1";

            auto method = "Access-Control-Request-Method" in req.headers;
            if (method && isAllowedMethod(*method))
                res.headers["Access-Control-Allow-Methods"] = *method;

            if (auto headers = "Access-Control-Request-Headers" in req.headers)
            {
                auto hds = split(*headers, ",").filter!(a => isAllowedHeader(a));
                res.headers["Access-Control-Allow-Headers"] = hds.join(",");
            }

            res.writeBody("");
            return;
        }
        else
            next(req, res);
    }


private:


    bool isAllowedOrigin(string origin) @safe
    {
        auto uri = URL(origin);
        auto val = fmt!"%s:%s"(uri.host, uri.port);
        return _allowOrigins.canFind(val);
    }


    bool isAllowedMethod(string method) @safe
    {
        return _allowMethods.canFind(method);
    }


    bool isAllowedHeader(string header) @safe
    {
        return _allowHeaders.canFind(header);
    }
}



class CorsWebMiddlewareFactory : BaseWebMiddlewareFactory!("CORS")
{
    WebMiddleware createComponent(Properties config)
    {
        string[] origins;
        foreach (Properties orp; config.getArray("origin"))
        {
            auto origin = parseOrigin(orp);
            origins ~= origin;
        }

        string[] methods;
        foreach (Properties mp; config.getArray("method"))
        {
            auto m = mp.get!string();
            configEnforce(!m.isNull, "Method must be a string");
            methods ~= m.get.toUpper;
        }

        string[] headers;
        foreach (Properties hp; config.getArray("header"))
        {
            auto h = hp.get!string();
            configEnforce(!h.isNull, "Header must be a string");
            headers ~= h.get.toLower;
        }

        auto ret = new CorsWebMiddleware(origins, methods, headers);
        ret.enabled = config.getOrElse!bool("enabled", false);
        return ret;
    }


private:


    string parseOrigin(Properties orp)
    {
        auto ors = orp.get!string();
        configEnforce(!ors.isNull, "Origin must be a string");

        auto seg = ors.get.split(":");
        configEnforce(seg.length < 3, "Origin specifies the domain and port");

        string host = seg[0];
        short port;

        try
            port = (seg.length == 1) ? 80 : to!short(seg[1]);
        catch (Exception e)
            throw new ConfigException("Origin port must be number");

        return fmt!"%s:%s"(host, port);
    }
}

