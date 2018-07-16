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
    import proped : Properties, Loader;
    import proped.loader : createPropertiesLoader;

    import vibe.core.log;

    import dango.system.commandline : CommandLineProcessor;
    import dango.system.container : ApplicationContainer;
}

private
{
    import std.array : empty;

    import poodinis : existingInstance;
    import vibe.core.core : runEventLoop, lowerPrivileges;

    import dango.system.properties : PropertiesContext;
    import dango.system.logging : configureLogging, LoggingContext;
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
    Properties loadProperties(string filePath);

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
        _propLoader = createPropertiesLoader();
        _container = new ApplicationContainer();
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

        Properties config;
        foreach(string cFile; configFiles)
            config ~= loadProperties(cFile);

        config ~= cProcessor.getOptionProperties();
        config ~= cProcessor.getEnvironmentProperties();

        // иницмализируем зависимостей
        doInitializeDependencies(config);
        configureLogging(container, config, &registerLogger);

        initializeDependencies(container, config);

        return runApplication(config);
    }


    Properties loadProperties(string filePath)
    {
        if (_propLoader is null)
            _propLoader = createPropertiesLoader();
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
    int runApplication(Properties config);

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
    void initializeDependencies(ApplicationContainer container, Properties config);


    void doInitializeDependencies(Properties config)
    {
        container.register!(Application, typeof(this)).existingInstance(this);
        container.registerContext!PropertiesContext;
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
    this(string name, string _version)
    {
        super(name, _version);
    }


    this(string name, SemVer _version)
    {
        super(name, _version);
    }


    final override int runApplication(Properties config)
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
    void initializeDaemon(Properties config);

    /**
     * Остановка демона сервисов
     * Params:
     *
     * exitStatus = Код завершения приложения
     */
    int finalizeDaemon(int exitStatus);

private:

    /**
     * Запуск основного цикла обработки событий
     * Params:
     *
     * config = Конфигурация приложения
     */
    int runLoop(Properties config)
    {
        logInfo("Запуск приложения %s (%s)", name, release);

        lowerPrivileges();

        initializeDaemon(config);

        logDiagnostic("Запуск цикла обработки событий...");
        int status = runEventLoop();
        logDiagnostic("Цикл событий зaвершен со статутом %d.", status);

        return finalizeDaemon(status);
    }
}

