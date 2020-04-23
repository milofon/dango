/**
 * Contains the implementation of application context setup.
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-18
 */

module dango.inject.context;

public
{
    import dango.inject.container : DependencyContainer;
}

private
{
    import dango.inject.injection : inject;
}


/**
 * Dependency context
 */
interface DependencyContext(A...)
{
    void registerDependencies(DependencyContainer container, A args) @safe;
}


/**
* Register dependencies through an dependency context.
*/
void registerContext(Context : DependencyContext!(A), A...)(DependencyContainer container) @safe
{
    auto context = new Context();
    context.registerDependencies(container);
    inject!Context(container, context);
}

