/**
 * Модуль HTML логера
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-18
 */

module dango.system.logging.loggers.html;

private
{
    import vibe.core.log : Logger, HTMLLogger, LogLevel;
    import vibe.core.concurrency : lock;

    import dango.system.logging.core;
    import dango.system.properties;
}


/**
 * Фабрика создающая HTML логгер
 */
class HTMLLoggerFactory : LoggerFactory
{
    shared(Logger) createComponent(UniConf config) @trusted
    {
        string fileName = config.opt!string("file").frontOr("dango.html");
        LogLevel level = matchLogLevel(config.opt!string("level").frontOr("info"));

        auto result = cast(shared)new HTMLLogger(fileName);
        {
            auto l = result.lock();
            l.unsafeGet.minLogLevel = level;
        }

        return result;
    }
}

