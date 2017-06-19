/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.logging;

public
{
    import dango.system.logging.core : configureLogging;
}

private
{
    import poodinis: ApplicationContext, DependencyContainer;

    import dango.system.logging.core;
    import dango.system.logging.loggers.consoled;
    import dango.system.logging.loggers.file;
    import dango.system.logging.loggers.html;

    import dango.system.container: registerByName;
}

/**
 * Контекст для регистрации компонентов отвечающих к логированию
 */
class LoggingContext : ApplicationContext
{
    public override void registerDependencies(shared(DependencyContainer) container)
    {   
        container.registerByName!(LoggerFactory, FileLoggerFactory)("FILE");
        container.registerByName!(LoggerFactory, HTMLLoggerFactory)("HTML");
        container.registerByName!(LoggerFactory, ConsoledLoggerFactory)("CONSOLE");
    }
}
