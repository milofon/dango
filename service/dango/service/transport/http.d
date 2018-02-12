/**
 * Модуль транспортного уровня на основе HTTP
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport.http;

private
{
    import std.exception : enforce;
    import std.format : fmt = format;

    import vibe.stream.operations : readAll;
    import vibe.inet.url : URL;
    import vibe.http.router;
    import vibe.http.client;
    import vibe.core.log;

    import dango.controller.core : createOptionCORSHandler, handleCors;
    import dango.controller.http : loadServiceSettings;

    import dango.service.transport.core;
}


class HTTPServerTransport : ServerTransport
{
    private
    {
        HTTPListener _listener;
    }


    void listen(RpcServerProtocol protocol, Properties config)
    {
        auto router = new URLRouter();
        auto httpSettings = loadServiceSettings(config);
        string entrypoint = config.getOrElse!string("entrypoint", "/");

        void handler(HTTPServerRequest req, HTTPServerResponse res)
        {
            handleCors(req, res);
            ubyte[] data = protocol.handle(req.bodyReader.readAll());
            res.writeBody(data);
        }

        router.post(entrypoint, &handler);
        router.match(HTTPMethod.OPTIONS, entrypoint, createOptionCORSHandler());

        _listener = listenHTTP(httpSettings, router);
    }


    void shutdown()
    {
        _listener.stopListening();
        logInfo("Transport HTTP Stop");
    }
}


class HTTPClientTransport : ClientTransport
{
    private
    {
        URL _entrypoint;
        bool _useTLS;
        HTTPClientSettings _settings;
        HTTPClient _client;
    }


    this(URL entrypoint, HTTPClientSettings settings)
    {
        validateEntrypoint(entrypoint);
        _entrypoint = entrypoint;
        _settings = settings;
        _useTLS = isUseTLS();

        auto port = _entrypoint.port;
        if( port == 0 )
            port = _useTLS ? 443 : 80;

        _client = new HTTPClient();
        _client.connect(getFilteredHost(_entrypoint), port, _useTLS, settings);
    }


    ubyte[] request(ubyte[] bytes)
    {
        auto res = _client.request((scope HTTPClientRequest req) {
            if (_entrypoint.localURI.length) {
                assert(_entrypoint.path.absolute, "Request URL path must be absolute.");
                req.requestURL = _entrypoint.localURI;
            }
            if (_settings.proxyURL.schema !is null)
                req.requestURL = _entrypoint.toString();
            if (_entrypoint.port && _entrypoint.port != _entrypoint.defaultPort)
                req.headers["Host"] = fmt("%s:%d", _entrypoint.host, _entrypoint.port);
            else
                req.headers["Host"] = _entrypoint.host;

            req.method = HTTPMethod.POST;
            req.writeBody(bytes);
        });

        // if( res.m_client )
        //     res.lockedConnection = _client;

        return res.bodyReader.readAll();
    }


private:


    void validateEntrypoint(URL url)
    {
        version(UnixSocket) {
            enforce(url.schema == "http" || url.schema == "https" || url.schema == "http+unix"
                    || url.schema == "https+unix", "URL schema must be http(s) or http(s)+unix.");
        } else {
            enforce(url.schema == "http" || url.schema == "https", "URL schema must be http(s).");
        }
        enforce(url.host.length > 0, "URL must contain a host name.");
    }


    bool isUseTLS()
    {
        if (_settings.proxyURL.schema !is null)
            return _settings.proxyURL.schema == "https";
        else
        {
            version(UnixSocket)
                return _entrypoint.schema == "https";
            else
                return _entrypoint.schema == "https"
                    || _entrypoint.schema == "https+unix";
        }
    }


    auto getFilteredHost(URL url)
    {
        version(UnixSocket)
        {
            import vibe.textfilter.urlencode : urlDecode;
            if (url.schema == "https+unix" || url.schema == "http+unix")
                return urlDecode(url.host);
            else
                return url.host;
        } else
            return url.host;
    }
}
