/**
 * Модуль для генерации http обработчиков
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.controller.http;

public
{
    import vibe.http.router : URLRouter;
    import vibe.http.server : HTTPServerRequest, HTTPServerResponse, HTTPServerRequestDelegate;
}

private
{
    import std.traits : getUDAs;
    import std.meta : Alias;

    import vibe.core.path : Path;

    import dango.controller.core;
}


/**
 * Аннотация для обозначение объекта контроллера
 * Params:
 *
 * prefix = Префикс для всех путей
 */
struct HTTPController
{
    string prefix;
}


/**
 * Аннотация для обозначения метода для обработки входящих запросов
 * Params:
 *
 * path   = Путь
 * method = Метод
 */
struct HTTPHandler
{
    string path;
    HTTPMethod method = HTTPMethod.GET;
}


/**
 * Аннотация для составления документации к методу
 * Params:
 *
 * helpText = Справочная информация о методе
 * params   = Информация о принимаемых параметрах в URL
 * query    = Информация о передаваемых параметрах запроса GET
 */
struct HTTPHandlerInfo
{
    string helpText;
    string[string] params;
    string[string] query;
}


/**
 * Аннотация для обозначения метода или контроллера
 * доступ к которым осуществляется только авторизованными пользователями
 */
enum Auth;


template isHTTPController(C)
{
    enum isHTTPController = is(C == class);
}


alias RegisterHandler(T) = void delegate(HTTPMethod, string, T);


string getHandlerPath(C)(string path)
{
    auto udas = getUDAs!(C, HTTPController);
    static if (udas.length > 0)
    {
        string prefix = udas[0].prefix;
        Path p = Path(prefix);
        p ~= (Path(path)).nodes;
        return p.toString();
    }
    else
        return path;
}


void registerController(C, Handler)(URLRouter router, C controller, RegisterHandler!Handler handler)
    if (isHTTPController!C)
{
    foreach (string fName; __traits(allMembers, C))
    {
        enum access = __traits(getProtection, __traits(getMember, C, fName));
        static if (access == "public")
        {
            alias member = Alias!(__traits(getMember, C, fName));
            foreach (attr; __traits(getAttributes, member))
            {
                static if (is(typeof(attr) == HTTPHandler))
                {
                    alias Type = typeof(&__traits(getMember, controller, fName));
                    static assert(is(Type == Handler), "Handler '" ~ fName ~ "' does not match the type");
                    handler(attr.method, getHandlerPath!C(attr.path),
                            &__traits(getMember, controller, fName));
                }
            }
        }
    }
}

