/**
 * Модуль транспортного уровня на основе Web application
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-04
 */

module dango.service.transport.web.transport;

private
{
    import vibe.http.client : HTTPClientSettings, requestHTTP, HTTPClientRequest;
    import vibe.inet.url : URL;
    import vibe.http.server : HTTPMethod;
    import vibe.stream.operations : readAll;

    import uniconf.core : Config;

    import dango.system.container;
    import dango.service.transport.core;
    import dango.web.server : WebApplicationServer;
}


/**
 * Серверный транспорт использующий функционал HTTP
 */
class WebServerTransport : ServerTransport
{
    private
    {
        WebApplicationServer _server;
    }


    this(WebApplicationServer server)
    {
        this._server = server;
    }


    void listen()
    {
        _server.listen();
    }


    void shutdown()
    {
        _server.shutdown();
    }
}


/**
 * Фабрика серверного транспорта использующего функционал HTTP
 */
class WebServerTransportFactory : ServerTransportFactory
{
    ServerTransport createComponent(Config config, ApplicationContainer container)
    {
        auto server = container.resolveNamedFactory!WebApplicationServer("router")
            .createInstance(config, container);
        return new WebServerTransport(server);
    }
}


/**
 * Клиентский транспорт использующий функционал HTTP
 */
class WebClientTransport : ClientTransport
{
    private
    {
        HTTPClientSettings _settings;
        URL _entrypoint;
    }


    this(string entrypoint, HTTPClientSettings settings = null)
    {
        this(URL(entrypoint), settings);
    }


    this(URL entrypoint, HTTPClientSettings settings = null)
    {
        _settings = (settings is null) ? new HTTPClientSettings() : settings;
        _entrypoint = entrypoint;
    }


    Future!Bytes request(Bytes bytes)
    {
        // TODO: потокобезопосность
        import vibe.core.concurrency;
        return async({
                auto res = requestHTTP(_entrypoint, (scope HTTPClientRequest req) {
                            req.method = HTTPMethod.POST;
                            req.writeBody(bytes);
                        }, _settings);
                return cast(Bytes)res.bodyReader.readAll();
            });
    }
}


/**
 * Фабрика клиенсткого транспорта использующего функционал HTTP
 */
class WebClientTransportFactory : ClientTransportFactory
{
    ClientTransport createComponent(Config config)
    {
        auto settings = new HTTPClientSettings();
        string entrypoint = config.getOrEnforce!string("entrypoint",
                "Not defined entrypoint for client transport");

        return new WebClientTransport(entrypoint, settings);
    }
}

