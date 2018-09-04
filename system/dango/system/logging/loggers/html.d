/**
 * Модуль HTML логера
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.logging.loggers.html;

private
{
    import vibe.core.log;
    import vibe.core.concurrency: lock;

    import dango.system.logging.core;
}


/**
 * Фабрика создающая HTML логгер
 */
class HTMLLoggerFactory : LoggerFactory
{
    shared(Logger) createLogger(Config config)
    {
        string fileName = config.getOrElse("file", "trand.html");
        LogLevel level = matchLogLevel(config.getOrElse("level", "info"));

        auto result = cast(shared)new HTMLLogger(fileName);
        {
            auto l = result.lock();
            l.minLogLevel = level;
        }

        return result;
    }
}

