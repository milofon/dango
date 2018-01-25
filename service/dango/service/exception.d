/**
 * Модуль содержит слассы ошибок и вспомогательные фунции
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.exception;

private
{
    import std.exception : enforceEx, enforce;

    import proped : Properties;

    import vibe.core.log : logError;
}


mixin template ExceptionMixin()
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        logError(msg);
        super(msg, file, line, next);
    }
}


/**
 * Исключение конфигурации приложения
 */
class ConfigException : Exception
{
    mixin ExceptionMixin!();
}


alias configEnforce = enforceEx!(ConfigException);


T getOrEnforce(T)(Properties config, string key, lazy string msg)
{
    static if (is(T == Properties))
        auto ret = config.sub(key);
    else
        auto ret = config.get!T(key);

    configEnforce(!ret.isNull, msg);
    return ret.get;
}



/**
 * Исключение транспорта
 */
class TransportException : Exception
{
    mixin ExceptionMixin!();
}


alias transportEnforce = enforceEx!(TransportException);
