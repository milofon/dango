/**
 * Модуль реализации Middleware CORS
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-21
 */

module dango.service.transport.middleware.cors;

private
{
    import std.algorithm.searching : canFind;
    import std.algorithm.iteration : filter;
    import std.format : fmt = format;
    import std.array : split, join;
    import std.conv : to;
    import std.uni : toLower, toUpper;

    import vibe.http.server : HTTPMethod;
    import vibe.inet.url : URL;
    import vibe.core.log;

    import dango.system.exception : configEnforce, ConfigException;

    import dango.service.transport.http;
}


/**
 * Добавляет заголовки для CORS
 */
class CorsHTTPMiddleware : BaseHTTPMiddleware!"CORS"
{
    private
    {
        string[] origins;
        string[] methods;
        string[] headers;
    }


    override void middlewareConfigure(Properties config)
    {
        foreach (Properties orp; config.getArray("origin"))
        {
            auto origin = parseOrigin(orp);
            logInfo("Add CORS origin %s", origin);
            origins ~= origin;
        }

        foreach (Properties mp; config.getArray("method"))
        {
            auto m = mp.get!string();
            configEnforce(!m.isNull, "Method must be a string");
            logInfo("Add CORS method %s", m);
            methods ~= m.get.toUpper;
        }

        foreach (Properties hp; config.getArray("header"))
        {
            auto h = hp.get!string();
            configEnforce(!h.isNull, "Header must be a string");
            logInfo("Add CORS header %s", h);
            headers ~= h.get.toLower;
        }
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        auto origin = "Origin" in req.headers;

        // Если Origin нет в запросе или его нет
        // в разрешенных то пропускаем дальше
        if (origin is null || !isAllowedOrigin(*origin))
        {
            nextRun(req, res);
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
            nextRun(req, res);
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


    bool isAllowedOrigin(string origin) @safe
    {
        auto uri = URL(origin);
        auto val = fmt!"%s:%s"(uri.host, uri.port);
        return origins.canFind(val);
    }


    bool isAllowedMethod(string method) @safe
    {
        return methods.canFind(method);
    }


    bool isAllowedHeader(string header) @safe
    {
        return headers.canFind(header);
    }
}

