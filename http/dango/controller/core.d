/**
 * Общий модуль для работы с HTTP контроллерами
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.controller.core;


public
{
    import vibe.http.router : URLRouter;
    import vibe.http.common : HTTPMethod;
    import vibe.http.server : HTTPServerRequestHandler;

    import proped : Properties;
}

private
{
    import vibe.http.server : HTTPServerRequest, HTTPServerResponse,
           HTTPServerRequestDelegate;
}


/**
 * Интерфейс для контроллера
 */
interface Controller
{
    /**
     * Инициализация контроллера
     * Params:
     *
     * config = Конфигурация контроллера
     */
    void initialize(Properties config);

    /**
     * Регистрация маршрутов контроллера
     * Params:
     *
     * router     = Маршрутизатор
     */
    void registerRoutes(URLRouter router);


    /**
     * Возвращает активность контроллера
     */
    bool enabled() @property;
}


void handleCors(HTTPServerRequest req, HTTPServerResponse res) @safe
{
    if (req.method == HTTPMethod.OPTIONS)
        return;

    if (auto origin = "Origin" in req.headers)
    {
        res.headers["Access-Control-Allow-Origin"] = *origin;
        res.headers["Access-Control-Allow-Credentials"] = "true";
    }
}


HTTPServerRequestDelegate createOptionCORSHandler() @safe
{
    void handler(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        auto origin = "Origin" in req.headers;
        if (origin is null)
            return;

        auto method = "Access-Control-Request-Method" in req.headers;
        if (method is null)
            return;

        res.headers["Access-Control-Allow-Origin"] = *origin;
        res.headers["Access-Control-Allow-Credentials"] = "true";
        res.headers["Access-Control-Max-Age"] = "1728000";
        res.headers["Access-Control-Allow-Methods"] = *method;

        if (auto headers = "Access-Control-Request-Headers" in req.headers)
            res.headers["Access-Control-Allow-Headers"] = *headers;

        res.writeBody("");
    }

    return &handler;
}

