/**
 * Модуль реализует концепцию Middleware
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.controller.middleware;

private
{
    import std.container.slist : SList;

    import vibe.http.server;
}


alias MiddlewareHandler(P...) = void delegate(P);


interface Middleware(P...)
{
    bool processRequest(P args);

    bool processResponse(P args);

    bool processException(P args);
}


abstract class BaseMiddleware(P...) : Middleware!P
{
    bool processRequest(P args)
    {
        return true;
    }


    bool processResponse(P args)
    {
        return true;
    }


    bool processException(P args)
    {
        return true;
    }
}


abstract class MiddlewareController(P...)
{
    alias Handler = MiddlewareHandler!P;

    protected
    {
        Middleware!P[] _middlewares;
    }


    void addMiddleware(Middleware!P middleware)
    {
        _middlewares ~= middleware;
    }


    bool requestHandler(P args)
    {
        foreach (mdw; _middlewares)
        {
            if (!mdw.processRequest(args))
                return false;
        }

        return true;
    }


    void responseHandler(P args)
    {
        foreach_reverse (mdw; _middlewares)
        {
            if (!mdw.processResponse(args))
                return;
        }
    }


    void exceptionHandler(Exception e, P args)
    {
        foreach_reverse (mdw; _middlewares)
        {
            if (!mdw.processException(args))
                return;
        }
    }
}


class HTTPMiddlewareController : MiddlewareController!(HTTPServerRequest, HTTPServerResponse), HTTPServerRequestHandler
{
    private
    {
        HTTPServerRequestHandler _handler;
    }


    this(HTTPServerRequestHandler handler)
    {
        _handler = handler;
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        () @trusted {
            if (!requestHandler(req, res))
                return;

            try
                _handler.handleRequest(req, res);
            catch (Exception e)
            {
                exceptionHandler(e, req, res);
                return;
            }

            responseHandler(req, res);
        } ();
    }
}

