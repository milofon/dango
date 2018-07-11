/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-05-30
 */

module dango.system.container;

public
{
    import poodinis : ApplicationContext, Autowire, autowire, CreatesSingleton;

    import dango.system.container.named : registerNamed, resolveNamed;
    import dango.system.container.component;
    import dango.system.container.context : registerContext, ConfigurableContext;
}

private
{
    import poodinis : DependencyContainer;
}


alias ApplicationContainer = shared(DependencyContainer);

