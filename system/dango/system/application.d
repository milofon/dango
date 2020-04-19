/**
 * The module implements application skeleton
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.application;

public
{
    import uniconf.core : UniConf;

    import dango.system.exception;
    import dango.system.logging;
    import dango.system.plugin : SemVer;
}

private
{
    import std.format : fmt = format;

    import vibe.core.log : logDiagnostic, registerLogger;
    import vibe.core.file : existsFile, readFileUTF8;
    import vibe.core.core : lowerPrivileges, runEventLoop;

    import commandr : Option, Command;
    import uniconf.core : loadConfig;

    import dango.inject : DependencyContainer, existingInstance, registerContext;
    import dango.system.logging.core : configureLogging;
    import dango.system.plugin;
}


/**
 * Интерфейс приложения
 */
interface Application
{
    /**
     * Функция загружает свойства из файла при помощи локального загрузчика
     * Params:
     *
     * filePath = Путь до файла
     *
     * Returns: Объект свойств
     */
    UniConf loadConfigFile(string filePath) @safe;

    /**
     * Возвращает глобальный объект настроек приложения
     */
    UniConf getConfig() pure nothrow @safe;

    /**
     * Возвращает глобальный контейнер зависимостей
     */
    DependencyContainer getContainer() pure nothrow @safe;
}


/**
 * Реализация приложения
 */
class DangoApplication : Application, PluginContainer!ConsolePlugin
{
    private @safe
    {
        string _applicationName;
        string _applicationSummary;
        SemVer _applicationVersion;

        string[] _defaultConfigs;
        UniConf _applicationConfig;
        ConsolePlugin[] _plugins;

        DependencyContainer _container;
        PluginManager _manager;
    }

    /**
     * Main application constructor
     */
    this()(string name, string _version, string summary) @safe
    {
        this(name, SemVer(_version), summary);
    }

    /**
     * Main application constructor
     */
    this()(string name, SemVer _version, string summary) @safe
    {
        this._applicationVersion = _version;
        this._applicationSummary = summary;
        this._applicationName = name;
        initializationConfigSystem();
        this._container = new DependencyContainer();
        this._manager = new PluginManager(_container);
    }

    /**
     * Свойство возвращает наименование приложения
     */
    string summary() pure nothrow @safe
    {
        return _applicationSummary;
    }

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() pure nothrow @safe
    {
        return _applicationVersion;
    }

    /**
     * Функция загружает свойства из файла при помощи локального загрузчика
     * Params:
     *
     * filePath = Путь до файла
     *
     * Returns: Объект свойств
     */
    UniConf loadConfigFile(string filePath) @safe
    {
        if (existsFile(filePath))
            return loadConfig(filePath);
        else
            throw new DangoApplicationException(
                    fmt!"Config file '%s' not found"(filePath));
    }

    /**
     * Возвращает глобальный объект настроек приложения
     */
    UniConf getConfig() pure nothrow @safe
    {
        return _applicationConfig;
    }

    /**
     * Возвращает глобальный контейнер зависимостей
     */
    DependencyContainer getContainer() pure nothrow @safe
    {
        return _container;
    }

    /**
     * Добавить путь до файла конфигурации
     * Params:
     *
     * filePath = Путь до файла
     */
    void addDefaultConfigFile(string filePath) @safe nothrow
    {
        _defaultConfigs ~= filePath;
    }

    /**
     * Регистрация плагина
     * Params:
     * plugin = Плагин для регистрации
     */
    void collectPlugin(ConsolePlugin plugin) @safe nothrow
    {
        _plugins ~= plugin;
    }

    /**
     * Возвращает менеджер плагинов
     */
    PluginManager getManager() @safe nothrow
    {
        return _manager;
    }

    /**
     * Запуск приложения
     *
     * Params:
     * args = Входящие параметры
     *
     * Returns: Код завершения работы приложения
     */
    int run(string[] args) @trusted
    {
        import commandr : parse;

        auto prog = new Program(_applicationName)
                .version_(_applicationVersion.toString)
                .summary(_applicationSummary);

        prog.add(new Option("c", "config", "Application config file"));

        foreach (ConsolePlugin plug; _plugins)
            plug.registerCommand(prog);

        auto progArgs = prog.parse(args);

        if (auto ret = runApplication(progArgs))
            return ret;

        foreach (ConsolePlugin plug; _plugins)
        {
            if (auto ret = plug.runCommand(progArgs))
                return ret;
        }

        return 0;
    }


private:

    /**
     * Run commnad
     */
    int runApplication(ProgramArgs prog) @trusted
    {
        auto configFiles = prog.options("config");
        if (!configFiles.length)
            configFiles = _defaultConfigs;

        foreach (string cFile; configFiles)
        {
            auto config = loadConfigFile(cFile);
            _applicationConfig = _applicationConfig ~ config;
        }

        initializeDependencies(_applicationConfig);
        configureLogging(_container, _applicationConfig, &registerLogger);

        return 0;
    }


    void initializeDependencies(UniConf config)
    {
        _container.register!(Application, typeof(this)).existingInstance(this);
        _container.registerContext!LoggingContext();
    }


    void initializationConfigSystem()() @trusted
    {
        import uniconf.core : registerConfigLoader, setConfigReader;

        setConfigReader((string path) {
                return readFileUTF8(path);
            });

        registerConfigLoader([".json"], (string data) {
                import uniconf.json : parseJson;
                return parseJson!UniConf(data);
            });

        version (Have_uniconf_yaml)
            registerConfigLoader([".yaml", ".yml"], (string data) {
                    import uniconf.yaml : parseYaml;
                    return parseYaml!UniConf(data);
                });

        version (Have_uniconf_sdlang)
            registerConfigLoader([".sdl"], (string data) {
                    import uniconf.sdlang : parseSDLang;
                    return parseSDLang!UniConf(data);
                });
    }
}















enum DAEMON_VERSION = "0.0.2";


/**
 * Реализация плагина для запуска приложения в фоне
 */
class DaemonApplication : PluginContainer!DaemonPlugin, ConsolePlugin
{
    private @safe
    {
        SemVer _release = SemVer(DAEMON_VERSION);
        DaemonPlugin[] _plugins;
    }

    /**
     * Свойство возвращает наименование приложения
     */
    string summary() pure nothrow @safe
    {
        return "Daemon application";
    }

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() pure nothrow @safe
    {
        return _release;
    }

    /**
     * Регистрация плагина
     * Params:
     * plugin = Плагин для регистрации
     */
    void collectPlugin(DaemonPlugin plug) @safe nothrow
    {
        _plugins ~= plug;
    }

    /**
     * Register command
     */
    void registerCommand(Program prog) @safe
    {
        auto comm = new Command("start", summary, release.toString)
                .add(new Option("uid", "user", "Sets the user name for privilege lowering."))
                .add(new Option("gid", "group", "Sets the group name for privilege lowering."));
        prog.add(comm);
    }

    /**
     * Run commnad
     */
    int runCommand(ProgramArgs args) @trusted
    {
        auto cmd = args.command();
        int ret = 0;
        if (cmd is null || cmd.name != "start")
            return ret;

    //         foreach (DaemonPlugin dp; _plugins)
    //         {
    //             ret = dp.startDaemon();
    //             if (ret)
    //                 return ret;
    //         }

        string uid = cmd.option("user");
        string gid = cmd.option("group");
        lowerPrivileges(uid, gid);

        import std.stdio: wl = writeln;
        wl("daemon start");
        logDiagnostic("Running event loop...");
    //         ret = runEventLoop();
        logDiagnostic("Event loop exited with status %d.", ret);

    //         foreach (DaemonPlugin dp; _plugins)
    //         {
    //             ret = dp.stopDaemon(ret);
    //             if (ret)
    //                 return ret;
    //         }

        return ret;
    }

    PluginManager getManager() @safe nothrow
    {
        return null;
    }
}


/+
    /**
     * Запуск основного цикла обработки событий
     * Params:
     *
     * config = Конфигурация приложения
     */
    int runLoop(Config config)
    {
        logInfo("Запуск приложения %s (%s)", name, release);

        lowerPrivileges();

        foreach (JobScheduler sh; resolveSystemSchedulers(container))
            _schedulers[sh.name.toUpper] = sh;

        foreach (Config jobConf; config.getArray("job").filter!(
                    c => c.getOrElse!bool("enabled", false)))
        {
            auto sh = resolveScheduler(container, jobConf);
            _schedulers[sh.name.toUpper] = sh;
        }

        initializeDaemon(config);

        foreach (JobScheduler job; _schedulers)
        {
            logInfo("Start job %s", job.name);
            job.start();
        }

        logDiagnostic("Запуск цикла обработки событий...");
        int status = runEventLoop();
        logDiagnostic("Цикл событий зaвершен со статуcом %d.", status);

        foreach (JobScheduler job; _schedulers)
            job.stop();

        return finalizeDaemon(status);
    }
}
+/

