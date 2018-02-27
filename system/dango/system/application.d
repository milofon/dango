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

    import poodinis : DependencyContainer, existingInstance;

    import vibe.core.log : registerLogger, logInfo, logDiagnostic;
    import vibe.core.core : runEventLoop, lowerPrivileges, runTask, Task;

    import dango.system.commandline : CommandLineProcessor;
    import dango.system.properties : PropertiesProxy;
}

private
{
    import std.array : empty;

    import dango.system.properties : createLoaderFromContainer, PropertiesContext;
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
     * Функция загружает свойства из файла при помощи локального загрузчика
     * Params:
     *
     * filePath = Путь до файла
     *
     * Returns: Объект свойств
     */
    Properties loadProperties(string filePath);

    /**
     * Свойство возвращает наименование приложения
     */
    string name() @property pure nothrow;

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() @property pure nothrow;
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
        shared(DependencyContainer) _container;
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
        _container = new shared(DependencyContainer)();
        _propLoader = createPropertiesLoader();

        // загружаем параметры командной строки
        auto cProcessor = new CommandLineProcessor(args);
        if (!doParseCommandLine(cProcessor))
            return 1;

        if (_configFiles.empty)
            _configFiles = getDefaultConfigFiles();

        Properties config;

        foreach(string cFile; _configFiles)
            config ~= loadProperties(cFile);

        config ~= cProcessor.getOptionProperties();
        config ~= cProcessor.getEnvironmentProperties();

        doInitDependencies(_container, config);

        configureLogging(container, config, &registerLogger);

        initDependencies(container, config);

        return runApplication(config);
    }

    /**
     * Свойство возвращает локальный контейнер
     */
    shared(DependencyContainer) container() @property pure nothrow
    {
        return _container;
    }

    /**
     * Свойство возвращает наименование приложения
     */
    string name() @property pure nothrow
    {
        return _applicationName;
    }

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() @property pure nothrow
    {
        return _applicationVersion;
    }

    /**
     * Функция загружает свойства из файла при помощи локального загрузчика
     */
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
     *
     * Example:
     * ---
     * initDependencies(container);
     * ---
     */
    void initDependencies(shared(DependencyContainer) container, Properties config)
    {
    }

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

private:

    void doInitDependencies(shared(DependencyContainer) container, Properties config)
    {
        container.registerContext!PropertiesContext;
        container.registerContext!LoggingContext;
        container.register!(Application, typeof(this)).existingInstance(this);
        container.register!PropertiesProxy.existingInstance(new PropertiesProxy(config));
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
abstract class DaemonApplication : BaseApplication
{
    this(string name, string _version)
    {
        super(name, _version);
    }


    this(string name, SemVer _version)
    {
        super(name, _version);
    }

protected:

    override final int runApplication(Properties config)
    {
        return runLoop(config);
    }

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

