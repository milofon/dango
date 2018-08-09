/**
 * Модуль содержит функции для работы с логами в приложении
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.logging.core;

private
{
    import std.uni: toUpper;
    import std.functional: toDelegate;
    import std.format: format, formattedWrite;

    import poodinis : ApplicationContext;
    import vibe.core.log;
    import proped: Properties;

    import dango.system.container : resolveNamed, registerNamed, ApplicationContainer;
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


/**
 * Интерфейс фабрики для создания объекта логгера
 */
interface LoggerFactory
{
    shared(Logger) createLogger(Properties config);
}



package LogLevel matchLogLevel(string level)
{
    switch (level.toUpper) with (LogLevel)
    {
        case "TRACE":
            return trace;
        case "DEBUGV":
            return debugV;
        case "DEBUG":
            return debug_;
        case "INFO":
            return info;
        case "WARN":
            return warn;
        case "ERROR":
            return error;
        case "FATAL":
            return fatal;
        default:
            return info;
    }
}



package FileLogger.Format matchLogFormat(string logFormat)
{
    switch (logFormat.toUpper) with (FileLogger.Format)
    {
        case "PLAIN":
            return plain;
        case "THREAD":
            return thread;
        case "THREADTIME":
            return threadTime;
        default:
            return plain;
    }
}


/**
 * Инициализация логирования приложения
 *
 * В основе функционала логирования используется реализация из vibed.
 * Значения по умолчанию: уровень логирования = warn, формат лога = plain
 *
 * Params:
 *
 * container = Контейнер DI
 * config    = Объект свойств содержит настройки логгеров
 * dg        = Функция для обработки логгера
 */
void configureLogging(ApplicationContainer container, Properties config, void function(shared(Logger)) nothrow dg)
{
    configureLogging(container, config, toDelegate(dg));
}


/**
 * Инициализация логирования приложения
 *
 * В основе функционала логирования используется реализация из vibed.
 * Значения по умолчанию: уровень логирования = warn, формат лога = plain
 *
 * Params:
 *
 * container = Контейнер DI
 * config    = Объект свойств содержит настройки логгеров
 * dg        = Функция-делегат для обработки логгера
 */
void configureLogging(ApplicationContainer container, Properties config, void delegate(shared(Logger)) nothrow dg)
{
    if ("logger" !in config)
        return;

    // отключаем логгер консоли по умолчанию
    setLogLevel(LogLevel.none);

    foreach (Properties loggerConf; config.getArray("logger"))
    {
        auto appender = loggerConf.get!string("appender");
        if (appender.isNull)
            throw new Exception("В конфигурации логера не указан тип ('%s')".format(loggerConf));

        auto factory = container.resolveNamed!LoggerFactory(appender.get.toUpper);
        if (factory is null)
            throw new Exception("Не зарегистрирован логгер с именем " ~ appender);

        shared(Logger) logger = factory.createLogger(loggerConf);
        if (logger && dg)
            dg(logger);
    }
}

