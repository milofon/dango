/**
 * Модуль планировщика задач
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-08-24
 */

module dango.system.scheduler;

private
{
    import core.time : Duration;

    import std.datetime : DateTime, Clock;
    import std.format : fmt = format;
    import std.array : appender;

    import vibe.core.core : Timer, setTimer, runWorkerTaskH, Task;
    import poodinis : Registration, ResolveOption, autowire;

    import uniconf.core : Config;
    import uniconf.core.exception : ConfigException;
    import cronexp : CronExpr, CronException;

    import dango.system.rx;
    import dango.system.inject;
    import dango.system.properties : getNameOrEnforce, enforceConfig;
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
alias JobFactory = ComponentFactory!(Job, Config);


/**
 * Интерфейс планировщика задач
 */
interface JobScheduler : NamedComponent, Observable!Job
{
    /**
     * Запуск задачи
     */
    void start();

    /**
     * Остановка задачи
     */
    void stop();
}


/**
 * Реализация планировщика задач на основе таймера vibed
 */
class TimerJobScheduler : JobScheduler
{
    private
    {
        const CronExpr _cron;
        const string _name;
        const Job _job;
        SubjectObject!Job _subject;
        Task _task;
    }


    this(Job job, CronExpr exp, string name)
    {
        this._subject = new SubjectObject!Job;
        this._name = name;
        this._cron = exp;
        this._job = job;
    }


    void start()
    {
        _task = runWorkerTaskH!(TimerJobScheduler.run)(cast(shared)this,
                cast(shared)_job);
    }


    void stop()
    {
        _task.interrupt();
        _subject.completed();
    }


    Disposable subscribe(Observer!Job observer)
    {
        return _subject.doSubscribe(observer);
    }


    string name() @property const
    {
        return _name;
    }


    void run(shared(Job) job) shared
    {
        Timer timer;

        void execute()
        {
            job.execute();
            timer.rearm(getNextDuration());
            (cast(SubjectObject!Job)_subject).put(cast(Job)job);
        }

        timer = setTimer(getNextDuration(), &execute);
    }


private:


    Duration getNextDuration() shared
    {
        auto now = cast(DateTime)Clock.currTime();
        return (cast(CronExpr)_cron).getNext(now) - now;
    }
}


/**
 * Фабрика по созданию планировщика задачи на основе конфига
 *
 * Params:
 * J = Тип задачи
 */
class JobSchedulerFactory(J : Job) : ComponentFactory!(JobScheduler,
        ApplicationContainer, Config)
{
    private
    {
        JobFactory _jobFactory;
        string _name;
    }


    this(JobFactory jobFactory, string name)
    {
        this._jobFactory = jobFactory;
        this._name = name;
    }


    final JobScheduler createComponent(ApplicationContainer container, Config config)
    {
        J job = cast(J)_jobFactory.createComponent(config);
        container.autowire!J(job);

        auto exp = config.getOrEnforce!string("cron",
                fmt!"Не определено cron выражение в задаче %s"(_name));
        try
            return new TimerJobScheduler(job, CronExpr(exp), _name);
        catch (CronException e)
            throw new ConfigException(
                    fmt!"Не верное cron выражение для задачи %s"(_name));
    }
}


/**
 * Фабрика по созданию планировщика задачи на основе строки cron
 *
 * Params:
 * J = Тип задачи
 */
class SystemJobSchedulerFactory(J : Job) : ComponentFactory!(JobScheduler,
        ApplicationContainer, string)
{
    private
    {
        JobFactory _jobFactory;
        string _name;
    }


    this(JobFactory jobFactory, string name)
    {
        this._jobFactory = jobFactory;
        this._name = name;
    }


    final JobScheduler createComponent(ApplicationContainer container, string cronExp)
    {
        Config config = Config(["cron": Config(cronExp)]);
        J job = cast(J)_jobFactory.createComponent(config);
        container.autowire!J(job);

        try
            return new TimerJobScheduler(job, CronExpr(cronExp), _name);
        catch (CronException e)
            throw new ConfigException(
                    fmt!"Не верное cron выражение для системной задачи %s"(_name));
    }
}


/**
 * Регистрация задачи с использованием пользовательской фабрики
 *
 * Params:
 * J         = Тип задачи
 * Name      = Имя задачи
 * container = Контейнер DI
 * factory   = Пользовательская фабрика
 */
Registration registerJob(J : Job, string Name)(ApplicationContainer container,
        JobFactory factory)
{
    auto jobSchFactory = new JobSchedulerFactory!J(factory, Name);
    return container.registerNamedExistingFactory!(TimerJobScheduler, Name)(
            jobSchFactory);
}


/**
 * Регистрация задачи с использованием встроенной фабрики на основе конструктора
 * задачи
 *
 * Params:
 * J         = Тип задачи
 * Name      = Имя задачи
 * container = Контейнер DI
 */
Registration registerJob(J : Job, string Name)(ApplicationContainer container)
{
    auto factory = new ComponentFactoryCtor!(Job, J, Config);
    return registerJob!(J, Name)(container, factory);
}


/**
 * Регистрация системной задачи с использованием пользовательской фабрики
 *
 * Params:
 * J         = Тип задачи
 * container = Контейнер DI
 * factory   = Пользовательская фабрика
 * cronExp   = Выражение cron
 */
Registration registerSystemJob(J : Job)(ApplicationContainer container,
        JobFactory factory, string cronExp)
{
    auto jobSchFactory = new SystemJobSchedulerFactory!J(factory, J.stringof);
    return registerExistingFactory!TimerJobScheduler(container,
            jobSchFactory, container, cronExp);
}


/**
 * Регистрация системной задачи с использованием встроееной фабрики на основе
 * конструктора задачи
 *
 * Params:
 * J         = Тип задачи
 * container = Контейнер DI
 * cronExp   = Выражение cron
 */
Registration registerSystemJob(J : Job)(ApplicationContainer container, string cronExp)
{
    auto factory = new ComponentFactoryCtor!(Job, J, Config);
    return registerSystemJob!(J)(container, factory, cronExp);
}


/**
 * Резолвинг ранее зарегистрированных фабрик планировщиков
 *
 * Params:
 * container = Контейнер DI
 */
JobScheduler[] resolveSystemSchedulers(ApplicationContainer container)
{
    auto ret = appender!(JobScheduler[]);

    foreach (factory; container.resolveAllFactory!(JobScheduler)(
                ResolveOption.noResolveException))
    {
        ret.put(factory.createInstance());
    }

    return ret.data;
}


/**
 * Создает на основе конфигов новый объект планировщика
 *
 * Params:
 * container = контейнер DI
 * config    = конфигурация задачи
 */
JobScheduler resolveScheduler(ApplicationContainer container, Config config)
{
    string jobName = getNameOrEnforce(config, "Не определено имя задачи");
    auto jobFactory = container.resolveNamedFactory!(JobScheduler)(
            jobName, ResolveOption.noResolveException);
    enforceConfig(jobFactory !is null, fmt!"Job '%s' not register"(jobName));
    return jobFactory.createInstance(container, config);
}

