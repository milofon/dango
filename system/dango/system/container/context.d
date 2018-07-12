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
    import proped : Properties;

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
    void registerDependencies(shared(DependencyContainer) container, Properties config);
}


/**
 * Регистрация контекста DI
 * Params:
 * container = DI контейнер
 * config    = Конфигурация
 */
void registerContext(Context : ApplicationContext)(shared(DependencyContainer) container,
        Properties config)
{
    auto context = new Context();

    static if (is(Context : ConfigurableContext))
        context.registerDependencies(container, config);
    else
        context.registerDependencies(container);

    context.registerContextComponents(container);
    container.register!(ApplicationContext, Context)().existingInstance(context);
    autowire(container, context);
}

