/**
 * Модуль содержит слассы ошибок и вспомогательные фунции
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-02-21
 */

module dango.system.exception;

private
{
    import std.exception : enforce;

    import proped : Properties;
}


mixin template ExceptionMixin()
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        import vibe.core.log : logError;
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


alias configEnforce = enforce!(ConfigException);

