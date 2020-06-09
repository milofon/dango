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
    import std.functional : toDelegate;

    import vibe.core.log : logDiagnostic, registerLogger;
    import vibe.core.path : NativePath;
    import vibe.core.file : existsFile, readFileUTF8, writeFile;
    import vibe.core.core : lowerPrivileges, runEventLoop;

    import commandr : Option, Command;
    import uniconf.core : loadConfig;

    import dango.inject : DependencyContainer, existingInstance, Inject,
            registerDependencyContext;
    import dango.system.logging.core : configureLogging;
    import dango.system.plugin;
}


/**
 * Интерфейс приложения
 */
interface Application
{
    /**
     * Свойство возвращает наименование приложения
     */
    string name() const pure @safe nothrow;

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() const pure @safe nothrow;

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
    const(UniConf) getConfig() const pure nothrow @safe;

    /**
     * Возвращает глобальный контейнер зависимостей
     */
    DependencyContainer getContainer() @safe nothrow;
}


/**
 * Делегат инициализации зависимостей
 */
alias DependencyBootstrap = void delegate(DependencyContainer cont, UniConf config) @safe;
alias DependencyBootstrapFn = void function(DependencyContainer cont, UniConf config) @safe;

/**
 * Делегат инициализации плагинов
 */
alias PluginBootstrap = void delegate(PluginManager manager) @safe;
alias PluginBootstrapFn = void function(PluginManager manager) @safe;

/**
 * Делегат инициализации приложения
 */
alias ApplicationBootstrap = void delegate(DependencyContainer cont, UniConf config) @safe;
alias ApplicationBootstrapFn = void function(DependencyContainer cont, UniConf config) @safe;


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
        PluginManager _pluginManager;
        DependencyBootstrap[] _dependencyBootstraps;
        ApplicationBootstrap[] _applicationBootstraps;
        PluginBootstrap[] _pluginBootstraps;
    }

    /**
     * Main application constructor
     */
    this(string name, string _version, string summary) @safe
    {
        this(name, SemVer(_version), summary);
    }

    /**
     * Main application constructor
     */
    this(string name, SemVer _version, string summary) @safe
    {
        this._applicationVersion = _version;
        this._applicationSummary = summary;
        this._applicationName = name;
        this._container = new DependencyContainer();
        this._pluginManager = new PluginManager(_container);
    }

    /**
     * Свойство возвращает наименование приложения
     */
    string name() const pure nothrow @safe
    {
        return _applicationName;
    }

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() const pure nothrow @safe
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
    const(UniConf) getConfig() const pure nothrow @safe
    {
        return _applicationConfig;
    }

    /**
     * Возвращает глобальный контейнер зависимостей
     */
    DependencyContainer getContainer() @safe nothrow
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
     * Добавить инициализатор зависимостей
     */
    void addDependencyBootstrap(DependencyBootstrap bst) @safe nothrow
    {
        _dependencyBootstraps ~= bst;
    }

    /**
     * Добавить инициализатор зависимостей
     */
    void addDependencyBootstrap(DependencyBootstrapFn bst) nothrow
    {
        _dependencyBootstraps ~= toDelegate(bst);
    }

    /**
     * Добавить инициализатор плагинов
     */
    void addPluginBootstrap(PluginBootstrap bst) @safe nothrow
    {
        _pluginBootstraps ~= bst;
    }

    /**
     * Добавить инициализатор плагинов
     */
    void addPluginBootstrap(PluginBootstrapFn bst) nothrow
    {
        _pluginBootstraps ~= toDelegate(bst);
    }

    /**
     * Добавить инициализатор приложения
     */
    void addApplicationBootstrap(ApplicationBootstrap bst) @safe nothrow
    {
        _applicationBootstraps ~= bst;
    }

    /**
     * Добавить инициализатор приложения
     */
    void addApplicationBootstrap(ApplicationBootstrapFn bst) nothrow
    {
        _applicationBootstraps ~= toDelegate(bst);
    }

    /**
     * Запуск приложения
     *
     * Params:
     * args = Входящие параметры
     *
     * Returns: Код завершения работы приложения
     */
    int run()(string[] args) @trusted
    {
        import commandr : parse;

        initializationApplicationConfig(args);
        initializeDependencies(_container, _applicationConfig);

        configureLogging(_container, _applicationConfig, &registerLogger);

        logInfo("Start application %s (%s)", _applicationName, _applicationVersion);

        _pluginManager.registerPluginContainer(this);
        foreach (bootstrap; _pluginBootstraps)
            bootstrap(_pluginManager);
        _pluginManager.initializePlugins();

        auto prog = new Program(_applicationName)
                .version_(_applicationVersion.toString)
                .summary(_applicationSummary);

        this.registerCommand(prog);
        foreach (ConsolePlugin plug; _plugins)
            plug.registerCommand(prog);

        auto progArgs = prog.parse(args);

        if (this.runCommand(progArgs))
            return 0;

        foreach (bootstrap; _applicationBootstraps)
            bootstrap(_container, _applicationConfig);

        foreach (ConsolePlugin plug; _plugins)
        {
            if (auto ret = plug.runCommand(progArgs))
                return ret;
        }

        return 0;
    }


private:


    /**
     * Регистрация обработчика команды dango
     */
    void registerCommand(Program prog) @trusted
    {
        auto dangoCommand = new Command("dango", "Dango utilities");
        dangoCommand.add(new Option(null, "saver", "Save application version to file").required());
        prog.add(dangoCommand);
        prog.defaultCommand(dangoCommand.name);
    }

    /**
     * Получение параметров командной строки
     */
    int runCommand(ProgramArgs progArgs) @trusted
    {
        int ret = 0;
        progArgs.on("dango", (cmdArgs) {
                auto versionFile = cmdArgs.option("saver");
                if (versionFile !is null && versionFile.length)
                    writeFile(NativePath(versionFile), cast(ubyte[])release.toString);
                ret = 1;
            });
        return ret;
    }


    void initializeDependencies(DependencyContainer container, UniConf config) @safe
    {
        container.register!(Application, typeof(this)).existingInstance(this);
        container.registerDependencyContext!LoggingContext();
        foreach (bootstrap; _dependencyBootstraps)
            bootstrap(container, config);
    }


    void initializationApplicationConfig()(ref string[] args) @trusted
    {
        import std.getopt : getopt, arraySep, gconfig = config;

        initializationConfigSystem();

        arraySep = ",";
        string[] configFiles;
        auto helpInformation = getopt(args,
                gconfig.passThrough,
                "c|config", &configFiles);

        if (helpInformation.helpWanted)
            args ~= "-h";

        if (!configFiles.length)
            configFiles = _defaultConfigs;

        foreach (string cFile; configFiles)
        {
            auto config = loadConfigFile(cFile);
            _applicationConfig = _applicationConfig ~ config;
        }
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


/**
 * Реализация плагина для запуска приложения в фоне
 */
class DaemonApplicationPlugin : PluginContainer!DaemonPlugin, ConsolePlugin
{
    private @safe
    {
        DaemonPlugin[] _plugins;
    }

    /**
     * Свойство возвращает наименование плагина
     */
    string name() pure @safe nothrow
    {
        return "Daemon";
    }

    /**
     * Свойство возвращает описание плагина
     */
    string summary() pure nothrow @safe
    {
        return "Daemon application";
    }

    /**
     * Свойство возвращает версию плагина
     */
    SemVer release() pure nothrow @safe
    {
        return SemVer(0, 0, 1);
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
        auto cmd = prog.getCommandOrCreate("start", summary, release.toString);
        cmd.add(new Option("uid", "user", "Sets the user name for privilege lowering."));
        cmd.add(new Option("gid", "group", "Sets the group name for privilege lowering."));
    }

    /**
     * Run commnad
     */
    int runCommand(ProgramArgs args) @trusted
    {
        import vibe.core.core : Timer, setTimer;
        import core.time : seconds;

        auto cmd = args.command();
        int ret = 0;
        if (cmd is null || cmd.name != "start")
            return ret;

        foreach (DaemonPlugin dp; _plugins)
        {
            ret = dp.startDaemon();
            if (ret)
                return ret;
        }

        string uid = cmd.option("user");
        string gid = cmd.option("group");
        lowerPrivileges(uid, gid);

        void emptyTimer() {}
        auto timer = setTimer(1.seconds, &emptyTimer, true);

        logDiagnostic("Running event loop...");
        ret = runEventLoop();
        logDiagnostic("Event loop exited with status %d.", ret);

        foreach (DaemonPlugin dp; _plugins)
        {
            ret = dp.stopDaemon(ret);
            if (ret)
                return ret;
        }

        return ret;
    }
}


/**
 * Возвращает команду или создает новую
 */
Command getCommandOrCreate(Command prog, string name, string summary, string ver) @safe
{
    if (auto cmd = name in prog.commands)
        return *cmd;
    else
    {
        auto cmd = new Command(name, summary, ver);
        prog.add(cmd);
        return cmd;
    }
}

