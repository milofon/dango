/**
 *
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-21
 */

module dango.service.transport.middleware.tokenauth;

private
{
    import dango.system.properties : getOrEnforce;

    import dango.service.transport.http;
}



class TokenAuthHTTPMiddleware : BaseHTTPMiddleware!"TOKENAUTH"
{
    private string _token;


    override void middlewareConfigure(Properties config)
    {
        _token = config.getOrEnforce!string("token",
                "Token API is not defined");
    }


    void handleRequest(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        auto token = "X-Auth-Token" in req.headers;
        if (!token || *token != _token)
        {
            res.writeBody("Need authentication", 403);
            return;
        }

        nextRun(req, res);
    }
}

