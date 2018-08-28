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

    import proped : Properties;
    import cronexp : CronExpr, CronException;

    import dango.system.exception : ConfigException;
    import dango.system.container;

    import dango.system.properties : getOrEnforce, configEnforce;
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



alias JobFactory = ComponentFactory!(Job, Properties);



class SimpleJobFactory(J : Job) : JobFactory
{
    J createComponent(Properties config)
    {
        return new J(config);
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
        Properties, ApplicationContainer)
{
    JobScheduler createComponent(Properties config, ApplicationContainer container)
    {
        auto jobFactory = container.resolveFactory!(Job, Properties)(N);
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



void registerJob(F : JobFactory, J : Job, string N)(ApplicationContainer container)
{
    container.registerNamedFactory!(F, J, N);
    auto f = new JobSchedulerFactory!N();
    container.registerNamedFactory!(JobSchedulerFactory!N, TimerJobScheduler!N, N)(f);
}



void registerJob(J : Job, string N)(ApplicationContainer container)
{
    container.registerJob!(SimpleJobFactory!J, J, N);
}

