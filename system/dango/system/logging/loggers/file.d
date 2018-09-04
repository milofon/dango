/**
 * Модуль файлового логера
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.logging.loggers.file;

private
{
    import vibe.core.log;
    import vibe.core.concurrency: lock;

    import dango.system.logging.core;
}


/**
 * Фабрика создающая файловый логгер
 */
class FileLoggerFactory : LoggerFactory
{
    shared(Logger) createLogger(Config config)
    {
        string fileName = config.getOrElse("file", "trand.log");
        LogLevel level = matchLogLevel(config.getOrElse("level", "info"));

        FileLogger.Format logFormat = matchLogFormat(config.getOrElse("errorFormat", "plain"));
        FileLogger.Format logInfoFormat = matchLogFormat(config.getOrElse("infoFormat", "plain"));

        auto result = cast(shared)new FileLogger(fileName);
        {
            auto l = result.lock();
            l.minLevel = level;
            l.format = logFormat;
            l.infoFormat = logInfoFormat;
        }

        return result;
    }
}
