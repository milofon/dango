/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-05-30
 */

module dango.system.inject;

public
{
    import poodinis : ApplicationContext, Autowire, autowire, CreatesSingleton,
            registerContext, ResolveException, ResolveOption,
            newInstance;

    import dango.system.inject.named : registerNamed, resolveNamed;
    import dango.system.inject.component;
    import dango.system.inject.context : registerConfigurableContext,
            ConfigurableContext;
    import dango.system.inject.exception;
}

private
{
    import poodinis : DependencyContainer;
}


alias ApplicationContainer = shared(DependencyContainer);

