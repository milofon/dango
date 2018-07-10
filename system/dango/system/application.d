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
}


/**
 * Интерфейс приложения с возможностью конфигурирования
 */
interface ConfigurableApplication : Application
{
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
     * Возвращает пути до файлов по-умолчанию
     */
    string[] getDefaultConfigFiles();

    /**
     * Запуск приложения
     *
     * Params:
     * config = Входящие параметры
     *
     * Returns: Код завершения работы приложения
     */
    int runApplication(Properties config);
}


/**
 * Интерфейс приложения с возможностью инициализировать зависимости
 */
interface DependenciesApplication : ConfigurableApplication
{
    /**
     * Инициализация зависимостей
     *
     * Params:
     * container = Контейнер DI
     * config = Конфигурация
     */
    void initializeDependencies(ApplicationContainer container, Properties config);

    /**
     * Инициализация зависимостей с глобальным конфигом
     *
     * Params:
     * container = Контейнер DI
     * config = Конфигурация
     */
    void initializeGlobalDependencies(ApplicationContainer container, Properties config);
}


/**
 * Базовый класс приложения
 */
abstract class BaseApplication : DependenciesApplication
{
    private
    {
        string _applicationName;
        SemVer _applicationVersion;

        Properties _config;

        string[] _configFiles;
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
    }

    /**
     * See_Also: Application.run
     */
    final int run(string[] args)
    {
        // иницмализируем зависимости
        auto container = new ApplicationContainer();
        _propLoader = createPropertiesLoader();

        // загружаем параметры командной строки
        auto cProcessor = new CommandLineProcessor(args);
        if (!doParseCommandLine(cProcessor))
            return 1;

        if (_configFiles.empty)
            _configFiles = getDefaultConfigFiles();

        foreach(string cFile; _configFiles)
            _config ~= loadProperties(cFile);

        _config ~= cProcessor.getOptionProperties();
        _config ~= cProcessor.getEnvironmentProperties();

        initApplicationDependencies(container, _config);
        configureLogging(container, _config, &registerLogger);

        return runApplication(_config);
    }

    /**
     * Создает новый контейнер на основе конфигурации
     */
    ApplicationContainer createContainer(Properties config)
    {
        auto container = new ApplicationContainer();
        initializeGlobalDependencies(container, _config);
        initializeDependencies(container, config);
        return container;
    }


    string name() @property pure nothrow
    {
        return _applicationName;
    }


    SemVer release() @property pure nothrow
    {
        return _applicationVersion;
    }


    Properties loadProperties(string filePath)
    {
        if (_propLoader is null)
            _propLoader = createPropertiesLoader();
        return _propLoader(filePath);
    }


    string helpText() @property
    {
        return _applicationName;
    }


    bool parseCommandLine(CommandLineProcessor processor)
    {
        return true;
    }


private:


    void initApplicationDependencies(ApplicationContainer container, Properties config)
    {
        container.register!(Application, typeof(this)).existingInstance(this);

        container.registerContext!PropertiesContext;
        container.registerContext!LoggingContext;
    }


    bool doParseCommandLine(CommandLineProcessor processor)
    {
        processor.readOption("config|c", &_configFiles, "Конфигурационный файл");

        bool ret = parseCommandLine(processor);
        ret &= processor.checkOptions();

        if (!ret)
            processor.printer(helpText);

        return ret;
    }
}


/**
 * Приложение запускающее обработчик событий
 * работающее в режиме демона
 */
interface DaemonApplication : ConfigurableApplication
{
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
}


/**
 * Базовая реализация приложения запускающее обработчик событий
 * работающее в режиме демона
 */
abstract class BaseDaemonApplication : BaseApplication, DaemonApplication
{
    this(string name, string _version)
    {
        super(name, _version);
    }


    this(string name, SemVer _version)
    {
        super(name, _version);
    }


    final int runApplication(Properties config)
    {
        return runLoop(config);
    }


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

