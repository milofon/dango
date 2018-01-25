/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.dispatcher;

public
{
    import dango.service.dispatcher.core :
        Dispatcher, DispatcherType;
}

private
{
    import poodinis : ApplicationContext, DependencyContainer, newInstance;
    import dango.system.container : registerByName;

    import dango.service.dispatcher.json : JsonDispatcher;
    import dango.service.dispatcher.msgpack : MsgPackDispatcher;
}



class DispatcherContext : ApplicationContext
{
    override void registerDependencies(shared(DependencyContainer) container)
    {
        container.registerByName!(Dispatcher, JsonDispatcher)("json").newInstance();
        container.registerByName!(Dispatcher, MsgPackDispatcher)("msgpack").newInstance();
    }
}
