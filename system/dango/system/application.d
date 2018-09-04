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
    import uniconf.core : Config;

    import vibe.core.log;

    import dango.system.commandline : CommandLineProcessor;
    import dango.system.container : ApplicationContainer;
}

private
{
    import std.array : empty;
    import std.format : fmt = format;

    import poodinis : existingInstance, ResolveException;
    import vibe.core.core : runEventLoop, lowerPrivileges;

    import uniconf.core.loader : Loader, createConfigLoader, ConfigLoader;

    import dango.system.container : resolveFactory, PostComponentFactory;
    import dango.system.properties : getNameOrEnforce, configEnforce;
    import dango.system.logging : configureLogging, LoggingContext;
    import dango.system.scheduler : JobScheduler;
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
    Config loadConfig(string filePath);

    /**
     * Контейнер DI приложения
     */
    ApplicationContainer container() @property pure nothrow;
}


/**
 * Базовый класс приложения
 */
abstract class BaseApplication : Application
{
    private
    {
        string _applicationName;
        SemVer _applicationVersion;
        ApplicationContainer _container;
        Loader _propLoader;
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

        ConfigLoader[] loaders;

        version(Have_uniconf_sdlang)
        {
            import uniconf.sdlang;
            loaders ~= new SdlangConfigLoader();
        }
        version (Have_uniconf_properd)
        {
            import uniconf.properd;
            loaders ~= new PropertiesConfigLoader();
        }
        version (Have_uniconf_json)
        {
            import uniconf.json;
            loaders ~= new JsonConfigLoader();
        }
        version (Have_uniconf_yaml)
        {
            import uniconf.yaml;
            loaders ~= new YamlConfigLoader();
        }

        _propLoader = createConfigLoader(loaders);
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
            config = config ~ loadConfig(cFile);

        config = config ~ cProcessor.getOptionConfig();
        config = config ~ cProcessor.getEnvironmentConfig();

        // иницмализируем зависимостей
        doInitializeDependencies(config);
        configureLogging(container, config, &registerLogger);

        initializeDependencies(container, config);

        return runApplication(config);
    }


    Config loadConfig(string filePath)
    {
        return _propLoader(filePath);
    }


protected:

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

    /**
     * Инициализация зависимостей
     *
     * Params:
     * container = Контейнер DI
     * config = Конфигурация
     */
    void initializeDependencies(ApplicationContainer container, Config config);


    void doInitializeDependencies(Config config)
    {
        container.register!(Application, typeof(this)).existingInstance(this);
        container.registerContext!LoggingContext;
    }


private:


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
 * Базовая реализация приложения запускающее обработчик событий
 * работающее в режиме демона
 */
abstract class BaseDaemonApplication : BaseApplication
{
    private JobScheduler[] _schedulers;


    this(string name, string _version)
    {
        super(name, _version);
    }


    this(string name, SemVer _version)
    {
        super(name, _version);
    }


    final override int runApplication(Config config)
    {
        return runLoop(config);
    }


protected:


    /**
     * Запуск демона сервисов
     * Params:
     *
     * config = Конфигурация приложения
     */
    void initializeDaemon(Config config) {}

    /**
     * Остановка демона сервисов
     * Params:
     *
     * exitStatus = Код завершения приложения
     */
    int finalizeDaemon(int exitStatus)
    {
        return exitStatus;
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

        foreach (Config jobConf; config.getArray("job"))
        {
            if (jobConf.getOrElse!bool("enabled", false))
            {
                string jobName = getNameOrEnforce(jobConf,
                        "Не определено имя задачи");
                auto jobFactory = container.resolveFactory!(JobScheduler,
                        Config, ApplicationContainer)(jobName);
                configEnforce(jobFactory !is null,
                        fmt!"Job '%s' not register"(jobName));
                logInfo("Start job '%s'", jobName);
                _schedulers ~= jobFactory.create(jobConf, container);
            }
        }

        try
        {
            auto factorys = container.resolveAll!(
                    PostComponentFactory!(JobScheduler, ApplicationContainer));

            foreach (jobFactory; factorys)
                _schedulers ~= jobFactory.create(container);
        }
        catch(ResolveException e) {}

        initializeDaemon(config);

        foreach (JobScheduler job; _schedulers)
            job.start();

        logDiagnostic("Запуск цикла обработки событий...");
        int status = runEventLoop();
        logDiagnostic("Цикл событий зaвершен со статутом %d.", status);

        foreach (JobScheduler job; _schedulers)
            job.stop();

        return finalizeDaemon(status);
    }
}

