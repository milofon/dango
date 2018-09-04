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

    import dango.system.container : ApplicationContainer;
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
    void registerDependencies(ApplicationContainer, Config config);
}


/**
 * Регистрация контекста DI
 * Params:
 * container = DI контейнер
 * config    = Конфигурация
 */
void registerConfigurableContext(Context : ApplicationContext)(ApplicationContainer container,
        Config config) if (is(Context : ConfigurableContext))
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
        void registerDependencies(ApplicationContainer container, Config config)
        {
            int a = cast(int)config.get!long("key").get;
            container.register!(IItem, Item).factoryInstance!ItemFactory(a);
        }
    }
}



unittest
{
    auto cnt = createContainer();
    Config config = Config(["key": Config(11)]);

    cnt.registerConfigurableContext!TestContext(config);
    auto item = cnt.resolve!IItem;
    assert(item.name == "ITEM");
    assert(item.val == 11);
}

