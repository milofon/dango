/**
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-11
 */

module dango.system.logging;

public
{
    import vibe.core.log : log, logError, logWarn, logInfo, logTrace, logDebug;
    import dango.system.logging.core : LoggerFactory;
}

private
{
    import uniconf.core : UniConf;
    import dango.inject : DependencyContainer, DependencyContext;
    import dango.system.logging.loggers.console;
    import dango.system.logging.loggers.file;
    import dango.system.logging.loggers.html;
}


/**
 * Контекст для регистрации компонентов отвечающих к логированию
 */
class LoggingContext : DependencyContext!()
{
    void registerDependencies(DependencyContainer container)
    {
        container.register!(LoggerFactory, HTMLLoggerFactory)("HTML");
        container.register!(LoggerFactory, ConsoleLoggerFactory)("CONSOLE");
        container.register!(LoggerFactory, FileLoggerFactory)("FILE");
    }
}

