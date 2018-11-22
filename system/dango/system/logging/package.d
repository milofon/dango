/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.logging;

public
{
    import vibe.core.log : log, logError, logWarn, logInfo, logTrace, logDebug;
    import dango.system.logging.core : LoggerFactory;
}

private
{
    import dango.system.container : ApplicationContainer, ApplicationContext,
            registerNamed;
    import dango.system.logging.loggers.console;
    import dango.system.logging.loggers.file;
    import dango.system.logging.loggers.html;
}


/**
 * Контекст для регистрации компонентов отвечающих к логированию
 */
class LoggingContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerNamed!(LoggerFactory, HTMLLoggerFactory, "HTML");
        container.registerNamed!(LoggerFactory, FileLoggerFactory, "FILE");
        container.registerNamed!(LoggerFactory, ConsoleLoggerFactory, "CONSOLE");
    }
}

