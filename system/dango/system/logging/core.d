/**
 * Модуль содержит функции для работы с логами в приложении
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-11
 */

module dango.system.logging.core;

public
{
    import uniconf.core : UniConf;
}

private
{
    import std.uni : toUpper;
    import std.functional : toDelegate;
    import std.format : fmt = format;

    import vibe.core.log : Logger, LogLevel, FileLogger, setLogLevel;

    import dango.inject : DependencyContainer, ComponentFactory;
    import dango.system.properties : getNameOrEnforce;
}


/**
 * Интерфейс фабрики для создания объекта логгера
 */
alias LoggerFactory = ComponentFactory!(shared(Logger), UniConf);


/**
 * Преобразует строку в уровеь логирования
 */
package LogLevel matchLogLevel(string level) @safe
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


/**
 * Преобразует строку в формат лога
 */
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
void configureLogging(DependencyContainer container, UniConf config,
        void function(shared(Logger)) nothrow dg) @trusted
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
void configureLogging(DependencyContainer container, UniConf config,
        void delegate(shared(Logger)) nothrow dg) @safe
{
    // отключаем логгер консоли по умолчанию
    setLogLevel(LogLevel.none);

    if ("logger" !in config)
        return;

    UniConf logConfig = config.get!UniConf("logger");
    if (logConfig.canMapping)
        logConfig = UniConf([logConfig]);

    foreach (UniConf loggerConf; logConfig.getSequence())
    {
        auto appender = loggerConf.opt!UniConf("appender");
        if (appender.isNull)
            throw new Exception(fmt!"В конфигурации логера не указан тип ('%s')"(loggerConf));

        string appenderName = appender.get.getNameOrEnforce(
                "Не указано наименование логгера").toUpper;

        auto factory = container.resolve!LoggerFactory(appenderName);
        if (factory is null)
            throw new Exception("Не зарегистрирован логгер с именем " ~ appenderName);

        shared(Logger) logger = factory.createComponent(loggerConf);
        if (logger && dg)
            () @trusted { dg(logger); }();
    }
}

