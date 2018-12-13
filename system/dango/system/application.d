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
    import BrightProof : SemVer;
    import uniconf.core : ConfigLoader;
    import uniconf.core.config : Config;

    import dango.system.commandline : CommandLineProcessor;
    import dango.system.container : ApplicationContainer;
    import dango.system.logging;
    import dango.system.properties : getNameOrEnforce;
}

private
{
    import std.algorithm.iteration : filter, map;
    import std.array : empty, array;
    import std.typecons : NullableRef;
    import std.uni : toUpper;

    import poodinis : existingInstance, ResolveException;
    import vibe.core.core : runEventLoop, lowerPrivileges;
    import vibe.core.log : registerLogger, logDiagnostic;

    import uniconf.core: ConfigLoaderMixin, LangConfigLoader,
            createUniConfigLoader = createConfigLoader;

    import dango.system.logging.core : configureLogging;
    import dango.system.logging : LoggingContext;
    import dango.system.container : registerContext;
    import dango.system.scheduler : JobScheduler, resolveScheduler,
            resolveSystemSchedulers;
}


/**
 * Интерфейс приложения
 */
interface Application
{
    /**
     * Запуск приложения
     *
     * Params:
     * args = Входящие параметры
     *
     * Returns: Код завершения работы приложения
     */
    int run(string[] args);

    /**
     * Свойство возвращает наименование приложения
     */
    string name() @property pure nothrow;

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() @property pure nothrow;

    /**
     * Функция загружает свойства из файла при помощи локального загрузчика
     * Params:
     *
     * filePath = Путь до файла
     *
     * Returns: Объект свойств
     */
    Config loadConfigFile(string filePath);

    /**
     * Контейнер DI приложения
     */
    ApplicationContainer container() @property pure nothrow;
}


/**
 * Интерфейс системного приложения
 */
interface ConsoleApplication : Application
{
    /**
     * Запуск приложения
     *
     * Params:
     * config = Входящие параметры
     *
     * Returns: Код завершения работы приложения
     */
    int runApplication(Config config);

    /**
     * Получение аргументов из командной строки
     *
     * Params:
     * processor = Объект для разбора командной строки
     *
     * Returns: Успешность получения свойств
     */
    bool parseCommandLine(CommandLineProcessor processor);

    /**
     * Возвращает строку помощи для консоли
     */
    string helpText() @property;

    /**
     * Возвращает пути до файлов по-умолчанию
     */
    string[] getDefaultConfigFiles();

    /**
     * Инициализация зависимостей
     *
     * Params:
     * container = Контейнер DI
     * config = Конфигурация
     */
    void initializeDependencies(ApplicationContainer container, Config config);
}


/**
 * Миксин для упрощенного создания метода создания загрузчика конфигов
 *
 * Это позволяет инициализировать все подключенные к проекту загрузчики из uniconf
 * Dub добавляет version типа Have_*, что позволяет формировать список загрузчиков
 */
mixin template InitializeConfigLoader()
{
    override ConfigLoader createConfigLoader()
    {
        import uniconf.core: ConfigLoaderMixin, LangConfigLoader,
                createUniConfigLoader = createConfigLoader;
        mixin ConfigLoaderMixin!();
        return createUniConfigLoader(getAvailableLoaders());
    }
}


/**
 * Базовый класс системного приложения
 */
abstract class BaseSystemApplication : ConsoleApplication
{
    private
    {
        string _applicationName;
        SemVer _applicationVersion;
        ApplicationContainer _container;
        ConfigLoader _configLoader;
    }


    this(string name, string _version)
    {
        this(name, SemVer(_version));
    }


    this(string name, SemVer _version)
    {
        _applicationName = name;
        _applicationVersion = _version;
        _container = new ApplicationContainer();
        _configLoader = createConfigLoader();
    }


    string name() @property pure nothrow
    {
        return _applicationName;
    }


    SemVer release() @property pure nothrow
    {
        return _applicationVersion;
    }


    ApplicationContainer container() @property pure nothrow
    {
        return _container;
    }

    /**
     * See_Also: Application.run
     */
    final int run(string[] args)
    {
        string[] configFiles;

        // загружаем параметры командной строки
        auto cProcessor = new CommandLineProcessor(args);
        if (!doParseCommandLine(cProcessor, configFiles))
            return 1;

        if (configFiles.empty)
            configFiles = getDefaultConfigFiles();

        Config config;
        foreach(string cFile; configFiles)
            config = config ~ loadConfigFile(cFile);

        config = config ~ cProcessor.getOptionConfig();
        config = config ~ cProcessor.getEnvironmentConfig();

        // иницмализируем зависимостей
        doInitializeDependencies(config);
        configureLogging(container, config, &registerLogger);

        initializeDependencies(container, config);

        return runApplication(config);
    }


    Config loadConfigFile(string filePath)
    {
        return _configLoader(filePath);
    }


protected:

    // Реализация методов по умолчанию

    /**
     * Получение аргументов из командной строки
     *
     * Params:
     * processor = Объект для разбора командной строки
     *
     * Returns: Успешность получения свойств
     */
    bool parseCommandLine(CommandLineProcessor processor)
    {
        return true;
    }

    /**
     * Возвращает строку помощи для консоли
     */
    string helpText() @property
    {
        return _applicationName;
    }

    /**
     * Возвращает пути до файлов по-умолчанию
     */
    string[] getDefaultConfigFiles()
    {
        return [];
    }


protected:

    // Методы для изменения поведения в системных потомках

    ConfigLoader createConfigLoader()
    {
        mixin ConfigLoaderMixin!();
        return createUniConfigLoader(getAvailableLoaders());
    }


    void doInitializeDependencies(Config config)
    {
        container.register!(Application, typeof(this)).existingInstance(this);
        container.registerContext!LoggingContext;
    }


    bool doParseCommandLine(CommandLineProcessor processor, ref string[] configFiles)
    {
        processor.readOption("config|c", &configFiles, "Конфигурационный файл");

        bool ret = parseCommandLine(processor);
        ret &= processor.checkOptions();

        if (!ret)
            processor.printer(helpText);

        return ret;
    }
}


/**
 * Интерфейс приложения демона
 */
interface DaemonApplication
{
    /**
     * Запуск демона сервисов
     * Params:
     *
     * config = Конфигурация приложения
     */
    void initializeDaemon(Config config);

    /**
     * Остановка демона сервисов
     * Params:
     *
     * exitStatus = Код завершения приложения
     */
    int finalizeDaemon(int exitStatus);

    /**
     * Возвращает зарегистированный в приложении планировщик
     *
     * Params:
     * jobName  = Имя задачи
     */
    NullableRef!JobScheduler getJobScheduler(string jobName);
}


/**
 * Базовая реализация приложения запускающее обработчик событий
 * работающее в режиме демона
 */
abstract class BaseDaemonApplication : BaseSystemApplication, DaemonApplication
{
    private JobScheduler[string] _schedulers;


    this(string name, string _version)
    {
        super(name, _version);
    }


    this(string name, SemVer _version)
    {
        super(name, _version);
    }


    final int runApplication(Config config)
    {
        return runLoop(config);
    }


    NullableRef!JobScheduler getJobScheduler(string jobName)
    {
        if (auto scheduler = jobName.toUpper in _schedulers)
            return NullableRef!JobScheduler(scheduler);
        return NullableRef!JobScheduler.init;
    }


protected:

    // Реализация методов по умолчанию

    int finalizeDaemon(int exitStatus)
    {
        return exitStatus;
    }


    override void doInitializeDependencies(Config config)
    {
        super.doInitializeDependencies(config);
        container.register!(DaemonApplication, typeof(this))
            .existingInstance(this);
    }


private:


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

