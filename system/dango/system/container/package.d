/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-05-30
 */

module dango.system.container;

public
{
    import dango.system.container.named : registerNamed, resolveNamed;
    import poodinis : ApplicationContext;
}

private
{
    import poodinis : DependencyContainer;
}


alias ApplicationContainer = shared(DependencyContainer);

