/**
 * Модуль работы с контекстом DI
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-11
 */

module dango.system.inject.context;

public
{
    import uniconf.core : Config;
}

private
{
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
            container.register!(Server, HTTPServer).factoryInstance!ServerFactory(
                config.get!string("host").get,
                config.get!ushort("port").get);
        }
    }
}



@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, FileStore);
    Config config = Config(["host": Config("192.168.0.1"), "port": Config(80)]);

    cnt.registerConfigurableContext!TestContext(config);
    auto server = cnt.resolve!Server;
    assert (server.host == "192.168.0.1");
    assert (server.port == 80);
}

