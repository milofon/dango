/**
 * Модуль общих абстракций контроллера REST
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-19
 */

module dango.service.protocol.rest.controller;

public
{
    import proped : Properties;

    import vibe.http.server : HTTPMethod, HTTPServerRequest, HTTPServerResponse;
}

private
{
    import std.traits;
    import std.meta : Alias;
    import std.format : fmt = format;
    import std.algorithm.searching : startsWith;

    import vibe.http.server : HTTPServerRequestDelegate;

    import dango.system.traits;

    import dango.service.global;
}


/**
 * Функция регистрации обработчика запроса
 */
alias RegisterHandler = void delegate(HTTPMethod, string, HTTPServerRequestDelegate);


/**
 * Аннотация для обозначение объекта контроллера
 * Params:
 *
 * prefix = Префикс для всех путей
 */
struct Controller
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
struct Handler
{
    string path;
    HTTPMethod method = HTTPMethod.GET;
}


/**
 * Интерфейс для контроллера
 */
interface RestController : Configurable!(Properties), Activated
{
    /**
     * Регистрация маршрутов контроллера
     * Params:
     *
     * router     = Маршрутизатор
     */
    void register(RegisterHandler hdl);
}


/**
  * Базовый класс для контроллеров
  * Params:
  * P = Тип потомка
  */
abstract class BaseRestController(P) : P, RestController
{
    private
    {
        bool _enabled;
    }


    final void configure(Properties config)
    {
        _enabled = config.getOrElse!bool("enabled", false);

        controllerConfigure(config);
    }


    bool enabled() @property
    {
        return _enabled;
    }


    void register(RegisterHandler hdl)
    {
        eachControllerMethods!P(cast(P)this, hdl);
    }


protected:


    void controllerConfigure(Properties config) {}
}


private:


void eachControllerMethods(C)(C controller, RegisterHandler hdl)
{
    string getFullPath(string path)
    {
        import vibe.core.path : InetPath;

        enum udas = getUDAs!(C, Controller);
        static if (udas.length > 0)
        {
            auto parent = InetPath(udas[0].prefix);
            auto child = InetPath(path);

            if (!parent.absolute)
                parent = InetPath("/") ~ parent;

            if (child.absolute)
            {
                auto childSegments = child.bySegment();
                childSegments.popFront();
                child = InetPath(childSegments);
            }

            if (!child.empty)
                parent ~= child;

            return parent.toString;
        }
        else
            return path;
    }

    foreach (string fName; __traits(allMembers, C))
    {
        static if(IsPublicMember!(C, fName))
        {
            alias member = Alias!(__traits(getMember, C, fName));
            enum udas = getUDAs!(member, Handler);

            static if (isCallable!member && udas.length > 0)
            {
                auto HDL = &__traits(getMember, controller, fName);
                static assert(is(typeof(HDL) == HTTPServerRequestDelegate),
                        "Handler '" ~ fName ~ "' does not match the type");
                hdl(udas[0].method, getFullPath(udas[0].path), HDL);
            }
        }
    }
}

