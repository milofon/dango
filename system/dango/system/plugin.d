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
    import std.traits;

    import dango.system.logging : logInfo;
    import dango.inject : DependencyContainer, inject;
    import dango.inject.provider : ClassProvider;
    import dango.system.exception;
}


/**
 * Интерфейс плагина
 */
interface Plugin
{
    /**
     * Свойство возвращает наименование плагина
     */
    string name() pure @safe nothrow;

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
     * Обработка контейнером нового плагина
     *
     * Params:
     * plugin = Плагин для добавления
     */
    void collectPlugin(P plugin) @safe;
}


/**
 * Plugin context
 */
interface PluginContext(P : Plugin, A...)
{
    void registerPlugins(P plugin, A args) @safe;
}


/**
 * Register plugin context
 */
void registerContext(Context : PluginContext!(P, A), P : Plugin, A...)(P plugin, A args) @safe
{
    auto ctx = new Context();
    ctx.registerPlugins(plugin, args);
}


/**
 * Плагин поддерживающий обработку консольных команд
 */
interface ConsolePlugin : Plugin
{
    /**
     * Свойство возвращает описание плагина
     */
    string summary() pure @safe nothrow;

    /**
     * Регистрация обработчика команды
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


/**
 * Менеджер плагинов
 */
class PluginManager
{
    private 
    {
        alias PluginCollect = void delegate(Plugin) @safe;

        struct PluginInfo
        {
            TypeInfo info;
            Plugin plugin;
        }

        DependencyContainer _dcontainer;
        PluginCollect[][TypeInfo] _containers;
        PluginInfo[] _registrations;
    }


    /**
     * Main constructor
     */
    this(DependencyContainer container) @safe nothrow
    {
        this._dcontainer = container;
    }

    /**
     * Регистрация плагина
     */
    P registerPlugin(P : Plugin)() @safe
        if (!is(P == Plugin))
    {
        P plugin;
        auto prov = new ClassProvider!(Plugin, P)(_dcontainer);
        prov.withProvided(true, (val) @trusted {
                plugin = cast(P)(*(cast(Object*)val));
            });
        return registerPlugin!P(plugin);
    }

    /**
     * Регистрация плагина
     */
    P registerPlugin(P : Plugin)(P plugin) @safe
        if (!is(P == Plugin))
    {
        static foreach (PI; InterfacesTuple!P)
        {
            static if (is(PI : PluginContainer!I, I : Plugin))
                registerPluginContainer!PI(plugin);
            static if (is(PI : Plugin) && !is(PI == Plugin))
                _registrations ~= PluginInfo(typeid(PI), plugin);
        }
        return plugin;
    }

    /**
     * Регистрация контейнера плагинов
     */
    void registerPluginContainer(C : PluginContainer!P, P)(C containerPlugin) @safe
    {
        _containers[typeid(P)] ~= delegate void(Plugin p) {
                containerPlugin.collectPlugin(cast(P)p);
            };
    }

    /**
     * Инициализация плагинов
     */
    void initializePlugins() @trusted
    {
        foreach (reg; _registrations)
        {
            if (reg.plugin is null || reg.info is null)
                throw new DangoPluginException("Error registration plugin");

            if (auto collectors = reg.info in _containers)
            {
                logInfo("Use plugin %s (%s) as %s", reg.plugin.name, reg.plugin.release, reg.info);
                foreach (collector; *collectors)
                    collector(reg.plugin);
            }
            else
                throw new DangoPluginException("Error initialize plugin. "
                        ~ "Not found container for plugin " ~ reg.info.toString);
        }
    }
}

