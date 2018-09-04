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

    import vibe.core.core;

    import uniconf.core.exception : ConfigException;
    import uniconf.core : Config;

    import cronexp : CronExpr, CronException;

    import dango.system.container;
    import dango.system.properties : configEnforce;
}


/**
 * Интерфес задачи
 */
interface Job
{
    /**
     * Запуск задачи
     */
    void execute();
}



alias JobFactory = ComponentFactory!(Job, Config);



class SimpleJobFactory(J : Job) : JobFactory
{
    J createComponent(Config config)
    {
        return createSimpleComponent!J(config);
    }
}



alias SystemJobFactory = ComponentFactory!Job;



class SimpleSystemJobFactory(J : Job) : SystemJobFactory
{
    J createComponent()
    {
        return new J();
    }
}



interface JobScheduler
{
    void start();


    void stop();
}



class TimerJobScheduler(string N) : JobScheduler
{
    private
    {
        Job _job;
        CronExpr _cron;
        Timer _timer;
    }


    this(Job job, CronExpr ce)
    {
        this._job = job;
        this._cron = ce;
    }


    void start()
    {
        void execute()
        {
            _job.execute();
            _timer = setTimer(getNextDuration(), &execute);
        }

        _timer = setTimer(getNextDuration(), &execute);
    }


    void stop()
    {
        _timer.stop();
    }


private:


    Duration getNextDuration()
    {
        auto now = cast(DateTime)Clock.currTime();
        return _cron.getNext(now) - now;
    }
}



class JobSchedulerFactory(string N) : ComponentFactory!(JobScheduler,
        Config, ApplicationContainer)
{
    JobScheduler createComponent(Config config, ApplicationContainer container)
    {
        auto jobFactory = container.resolveFactory!(Job, Config)(N);
        auto job = jobFactory.create(config);

        auto exp = config.getOrEnforce!string("cron",
                fmt!"Не определено cron выражение в задаче %s"(N));

        try
            return new TimerJobScheduler!N(job, CronExpr(exp));
        catch (CronException e)
            throw new ConfigException(
                    fmt!"Не верное cron выражение для задачи %s"(N));
    }
}



class SystemJobSchedulerFactory(string N) : ComponentFactory!(JobScheduler,
        ApplicationContainer)
{
    private string _cronExp;


    this(string cronExp)
    {
        this._cronExp = cronExp;
    }


    JobScheduler createComponent(ApplicationContainer container)
    {
        auto jobFactory = container.resolveFactory!(Job)(N);
        auto job = jobFactory.create();

        try
            return new TimerJobScheduler!N(job, CronExpr(_cronExp));
        catch (CronException e)
            throw new ConfigException(
                    fmt!"Не верное cron выражение для задачи %s"(N));
    }
}



void registerJob(F : JobFactory, J : Job, string N)(ApplicationContainer container)
{
    container.registerNamedFactory!(F, J, N);
    auto f = new JobSchedulerFactory!N();
    container.registerNamedFactory!(JobSchedulerFactory!N, TimerJobScheduler!N, N)(f);
}



void registerSystemJob(F : SystemJobFactory, J : Job, string N)(
        ApplicationContainer container, string cronExp)
{
    container.registerNamedFactory!(F, J, N);
    auto f = new SystemJobSchedulerFactory!N(cronExp);
    container.registerNamedFactory!(SystemJobSchedulerFactory!N, TimerJobScheduler!N, N)(f);
}



void registerJob(J : Job, string N)(ApplicationContainer container)
{
    container.registerJob!(SimpleJobFactory!J, J, N);
}



void registerSystemJob(J : Job, string N)(ApplicationContainer container, string cronExp)
{
    container.registerSystemJob!(SimpleSystemJobFactory!J, J, N)(cronExp);
}

