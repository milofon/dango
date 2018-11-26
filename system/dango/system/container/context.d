/**
 * Модуль работы с контекстом DI
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-11
 */

module dango.system.container.context;

private
{
    import uniconf.core : Config;

    import poodinis : ApplicationContext, DependencyContainer,
           registerContextComponents, autowire, existingInstance;
}


/**
 * Контекст DI с возможностью конфигурации
 */
interface ConfigurableContext
{
    /**
     * Регистрация зависимостей
     * Params:
     * container = DI контейнер
     * config    = Конфигурация
     */
    void registerDependencies(shared(DependencyContainer) container, Config config);
}


/**
 * Регистрация контекста DI
 * Params:
 * container = DI контейнер
 * config    = Конфигурация
 */
void registerConfigurableContext(Context : ApplicationContext)(
        shared(DependencyContainer) container, Config config)
if (is(Context : ConfigurableContext))
{
    auto context = new Context();
    context.registerDependencies(container, config);
    context.registerContextComponents(container);
    container.register!(ApplicationContext, Context)().existingInstance(context);
    autowire(container, context);
}



version(unittest)
{
    import dango.system.container.component;

    class TestContext : ApplicationContext, ConfigurableContext
    {
        void registerDependencies(shared(DependencyContainer) container, Config config)
        {
            container.register!(IItem, Item).factoryInstance!IItemFactory(
                config.get!string("key").get,
                config.get!double("val").get);
        }
    }
}



@system unittest
{
    auto cnt = createContainer();
    Config config = Config(["key": Config("ITEM"), "val": Config(1.1)]);

    cnt.registerConfigurableContext!TestContext(config);
    auto item = cnt.resolve!IItem;
    assert (item.verify("ITEM", 1.1, 1));
}

