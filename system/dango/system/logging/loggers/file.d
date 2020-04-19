/**
 * Модуль файлового логера
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-18
 */

module dango.system.logging.loggers.file;

private
{
    import vibe.core.log : FileLogger, Logger, LogLevel;
    import vibe.core.concurrency: lock;

    import dango.system.logging.core;
    import dango.system.properties;
}


/**
 * Фабрика создающая файловый логгер
 */
class FileLoggerFactory : LoggerFactory
{
    shared(Logger) createComponent(UniConf config) @trusted
    {
        string fileName = config.opt!string("file").frontOr("dango.log");
        LogLevel level = matchLogLevel(config.opt!string("level").frontOr("info"));

        FileLogger.Format logFormat = matchLogFormat(
                config.opt!string("errorFormat").frontOr("plain"));
        FileLogger.Format logInfoFormat = matchLogFormat(
                config.opt!string("infoFormat").frontOr("plain"));

        auto result = cast(shared)new FileLogger(fileName);
        {
            auto l = result.lock();
            l.unsafeGet.minLevel = level;
            l.unsafeGet.format = logFormat;
            l.unsafeGet.infoFormat = logInfoFormat;
        }

        return result;
    }
}

