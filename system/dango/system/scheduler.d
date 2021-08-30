/**
 * Модуль планировщика задач
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-21
 */

module dango.system.scheduler;

public
{
    import uniconf.core : UniConf;
}

private
{
    import core.time : Duration;
    import core.thread : Thread;
    import core.sync.condition : Condition;
    import core.sync.mutex : Mutex;

    import std.algorithm.iteration : filter;
    import std.datetime : DateTime, Clock;
    import std.exception : assumeWontThrow;
    import std.format : fmt = format;
    import std.traits : hasMember;
    import std.uni : toUpper;

    import vibe.core.core : Timer, setTimer;
    import vibe.core.log : logException;
    import cronexp : CronExpr, CronException;
    import dango.inject;

    import dango.system.logging : logWarn, logInfo, logDebug;
    import dango.system.application : Application;
    import dango.system.exception : DangoConfigException;
    import dango.system.properties;
    import dango.system.plugin;
}


/**
 * Интерфес задачи
 */
interface Job
{
    /**
     * Запуск задачи
     */
    void execute() shared;
}


/**
 * Фабрика задачи планировщика 
 */
alias JobFactory = ComponentFactory!(Job, DependencyContainer, UniConf);

/**
 * Контекст регистрации задач планировщика
 */
alias SchedulerContext = PluginContext!(SchedulerPlugin);


/**
 * Плагин управления задач планировщика
 */
class SchedulerPlugin : DaemonPlugin
{
    private @safe
    {
        DependencyContainer _container;
        UniConf _config;

        SchedulerFactory[string] _schedulerFactorys;
        SysSchedulerFactory[] _sysSchedulerFactorys;
        JobScheduler[] _schedulers;
    }

    /**
     * Main constructor
     */
    @Inject
    this(Application application)
    {
        this._container = application.getContainer();
        this._config = application.getConfig();
    }

    /**
     * Свойство возвращает наименование плагина
     */
    string name() pure @safe nothrow
    {
        return "Scheduler";
    }

    /**
     * Свойство возвращает версию приложения
     */
    SemVer release() pure @safe nothrow
    {
        return SemVer(0, 0, 1);
    }

    /**
     * Запуск процесса
     */
    int startDaemon()
    {
        foreach (sysFactory; _sysSchedulerFactorys)
            _schedulers ~= sysFactory(_container);

        auto schedulerConf = _config.opt!UniConf("scheduler");
        if (!schedulerConf.isNull)
        {
            auto jobsConfig = schedulerConf.get.opt!UniConf("job");
            if (!jobsConfig.isNull)
            {
                foreach (UniConf jobConf; jobsConfig.get.toSequence.filter!(
                            c => c.getOrElse!bool("enabled", false)))
                {
                    string jobName = getNameOrEnforce(jobConf, "Not defined job name");
                    if (auto factory = jobName.toUpper in _schedulerFactorys)
                        _schedulers ~= (*factory)(_container, jobConf);
                    else
                        throw new DangoConfigException("Job '" ~ jobName ~ "' not register");
                }
            }
            else
                logWarn("Not found jobs configuration");
        }
        else
            logWarn("Not found scheduler configuration");

        logInfo("Start scheduler");

        foreach (JobScheduler scheduler; _schedulers)
        {
            logInfo("  Start job [%s]", scheduler.name);
            scheduler.start();
        }

        return 0;
    }

    /**
     * Остановка процесса
     *
     * Params:
     * exitStatus = Код завершения приложения
     */
    int stopDaemon(int exitStatus)
    {
        logInfo("Stop scheduler");
        foreach (JobScheduler scheduler; _schedulers)
        {
            scheduler.stop();
            logInfo("  Stop job [%s]", scheduler.name);
        }
        return 0;
    }

    /**
     * Регистрация задачи
     */
    void registerJob(J : Job)(string name) @safe
    {
        alias JF = ComponentFactoryCtor!(Job, J, UniConf);
        registerJob!(JF)(name);
    }

    /**
     * Регистрация задачи с использованием фабрики
     */
    void registerJob(JF : JobFactory)(string name) @safe
    {
        auto factory = new WrapDependencyFactory!(JF)();
        registerJob!JF(name, factory);
    }

    /**
     * Регистрация задачи с использованием существующей фабрики
     */
    void registerJob(JF : JobFactory)(string name, JobFactory factory) @safe
    {
        string uName = name.toUpper;
        JobScheduler creator(DependencyContainer container, UniConf config) @safe
        {
            auto expStr = config.getOrEnforce!string("cron",
                fmt!"Not defined cron expression in task '%s'"(name));

            CronExpr cronExp = () @trusted {
                try
                    return CronExpr(expStr);
                catch (CronException e)
                    throw new DangoConfigException(
                        fmt!"Incorrect cron expression in task '%s'"(name));
            }();

            Job job = factory.createComponent(container, config);
            return new TimerJobScheduler(name, job, cronExp);
        }
        _schedulerFactorys[uName] = &creator;
    }

    /**
     * Регистрация системной задачи
     */
    void registerSystemJob(J : Job)(string cronStr) @safe
    {
        alias JF = ComponentFactoryCtor!(Job, J, UniConf);
        registerSystemJob!(JF)(cronStr);
    }

    /**
     * Регистрация системной задачи с использованием фабрики
     */
    void registerSystemJob(JF : JobFactory)(string cronStr) @safe
    {
        auto factory = new WrapDependencyFactory!(JF)();
        registerSystemJob!JF(cronStr, factory);
    }

    /**
     * Регистрация системной задачи с использованием существующей фабрики
     */
    void registerSystemJob(JF : ComponentFactory!(C, A), C, A...)(string cronStr, JobFactory factory) @safe
    {
        static if (hasMember!(JF, "ConcreteType"))
            string title = typeid(JF.ConcreteType).toString;
        else static if (hasMember!(JF, "ComponentType"))
            string title = typeid(JF.ComponentType).toString;
        else
            string title = typeid(JF).toString;

        JobScheduler creator(DependencyContainer container) @safe
        {
            UniConf config = UniConf([
                    "__name": UniConf(title),
                    "enabled": UniConf(true),
                    "cron": UniConf(cronStr)
            ]);

            CronExpr cronExp = () @trusted {
                try
                    return CronExpr(cronStr);
                catch (CronException e)
                    throw new DangoConfigException(
                        fmt!"Incorrect cron expression in task '%s'"(title));
            }();

            Job job = factory.createComponent(container, config);
            return new TimerJobScheduler(title, job, cronExp);
        }
        _sysSchedulerFactorys ~= &creator;
    }
}


/**
  * Задача по выводу информации в консоль о GC
  */
class GarbageCollectorStatJob : Job
{
    /**
     * Запуск задачи
     */
    void execute() shared
    {
        import core.memory : GC;
        auto profileStats = GC.profileStats;
        auto stats = GC.stats;
        logInfo("== GC stats ==");
        logInfo("  Use memory in heap: %s", humanizeSize(stats.usedSize));
        logInfo("  Free memory in heap: %s", humanizeSize(stats.freeSize));
        auto total = stats.freeSize + stats.usedSize;
        logInfo("  Total memory in heap: %s", humanizeSize(total));
        logInfo("  GC runs: %s", profileStats.numCollections);
    }


private:


    string humanizeSize(size_t size) shared
    {
        enum SUFFIXES = ["", "K", "M", "G"];
        double dsize = size;
        ubyte suffix = 0;
        while (dsize > 1024 && suffix < 4)
        {
            dsize /= 1024;
            suffix++;
        }
        return fmt!"%.02f%s"(dsize, SUFFIXES[suffix]);
    }
}


/**
  * Задача по запуску минимизации используемой GC памяти
  */
class GarbageCollectorMinimizeJob : Job
{
    /**
     * Запуск задачи
     */
    void execute() shared
    {
        import core.memory : GC;
        GC.collect();
        GC.minimize();
    }
}


private:


/**
 * Интерфейс планировщика задач
 */
interface JobScheduler
{
    /**
     * Возвращает наименование задачи
     */
    string name() @safe nothrow;

    /**
     * Запуск задачи
     */
    void start();

    /**
     * Остановка задачи
     */
    void stop();
}


alias SchedulerFactory = JobScheduler delegate(DependencyContainer container, UniConf config) @safe;
alias SysSchedulerFactory = JobScheduler delegate(DependencyContainer container) @safe;


/**
 * Реализация планировщика задач на основе таймера vibed
 */
class TimerJobScheduler : Thread, JobScheduler
{
    private
    {
        CronExpr _expression;
        bool _isRunning;
        string _name;
        Mutex _mutex;
        Condition _condition;
        shared(Job) _job;
    }

    /**
     * Main constructor
     */
    this(string name, Job job, CronExpr cronExp) @trusted
    {
        super(&worker);
        this._expression = cronExp;
        this._name = name;
        this._job = cast(shared)job;
        this._mutex = new Mutex();
        this._condition = new Condition(this._mutex);
    }

    /**
     * Возвращает наименование задачи
     */
    string name() @safe nothrow
    {
        return _name;
    }

    /**
     * Запуск задачи
     */
    override void start() nothrow
    {
        _isRunning = true;

        Timer timer;
        void execute()
        {
            synchronized(_mutex)
                _condition.notify();
            timer.rearm(getNextDuration(), true);
        }
        timer = setTimer(getNextDuration(), &execute, true);

        super.start();
    }

    /**
     * Остановка задачи
     */
    void stop()
    {
        _isRunning = false;
        synchronized(_mutex)
            _condition.notify();
    }


private:


    void worker()
    {
        while (_isRunning)
        {
            synchronized(_mutex)
                _condition.wait();
            if (!_isRunning) 
                return;
            logDebug("Starting job '%s'", _name);
            auto interval = getNextDuration();
            try
                _job.execute();
            catch (Exception e)
                logException(e, fmt!"Job error '%s'"(_name));
            logDebug("Done '%s' next run in '%s'", _name, interval);
        }
    }

    /**
     * Вычисление интервала
     */
    Duration getNextDuration() nothrow
    {
        auto now = cast(DateTime)Clock.currTime();
        return assumeWontThrow(_expression.getNext(now)).get - now;
    }
}

