/**
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-11
 */

module dango.inject;

public
{
    import dango.inject.container : DependencyContainer;
    import dango.inject.factory : ComponentFactory, ComponentFactoryCtor, WrapDependencyFactory;
    import dango.inject.provider : Provider, singleInstance, newInstance, existingInstance;
    import dango.inject.context : DependencyContext, registerDependencyContext;
    import dango.inject.injection : inject, Inject, Named;
}

