/**
 * The module implements plugin system
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-03-27
 */

module dango.system.plugin;

public
{
    import BrightProof : SemVer;
    import commandr : Program, ProgramArgs;
}

private
{
    import dango.inject.container;
}


class PluginManager
{
@safe:
    private DependencyContainer _container;

    /**
     * Main constructor
     */
    this(DependencyContainer container)
    {
        this._container = container;
    }

    /**
     * Инициализация плагина
     *
     * Params:
     * plugin = Плагин для инициализации
     */
    void initializePlugin(P : Plugin)(P plugin)
    {
        // TODO: autoware plugin
        pragma (msg, "manager defined plugin -> ", P);
    }
}


/**
 * Интерфейс плагина
 */
interface Plugin
{
    /**
     * Свойство возвращает наименование приложения
     */
    string summary() pure @safe nothrow;

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() pure @safe nothrow;
}


/**
 * Интерфейс контейнера плагинов
 */
interface PluginContainer(P : Plugin)
{
    /**
     * Возвращает менеджер плагинов
     */
    PluginManager getManager() @safe;

    /**
     * Регистрация плагина в контейнер
     *
     * Params:
     * plugin = Плагин для регистрации
     */
    final void registerPlugin(PP : P)(PP plug) @safe
    {
        auto manager = getManager();
        if (manager)
            manager.initializePlugin!(PP)(plug);
        collectPlugin(plug);
    }

    /**
     * Обработка контейнером нового плагина
     *
     * Params:
     * plugin = Плагин для добавления
     */
    void collectPlugin(P plugin) @safe nothrow;
}


/**
 * Плагин поддерживающий обработку консольных команд
 */
interface ConsolePlugin : Plugin
{
    /**
     * Регистрация обработцика команды
     *
     * Params:
     * prog = Объект программы
     */
    void registerCommand(Program prog) @safe;

    /**
     * Получение параметров командной строки
     *
     * Params:
     * pArgs = Обработчик аргументов
     */
    int runCommand(ProgramArgs pArgs) @safe;
}


/**
 * Плагин поддерживающий работу в фоновом режиме
 */
interface DaemonPlugin : Plugin
{
    /**
     * Запуск процесса
     */
    int startDaemon();

    /**
     * Остановка процесса
     *
     * Params:
     * exitStatus = Код завершения приложения
     */
    int stopDaemon(int exitStatus);
}

