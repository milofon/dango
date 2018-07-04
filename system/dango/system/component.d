/**
 * Модуль работы с компонентами и фабриками к ним
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-26
 */

module dango.system.component;

public
{
    import proped : Properties;

    import dango.system.container : ApplicationContainer;
}


private
{
    import std.traits : Parameters;
    import std.meta : AliasSeq;

    import poodinis : Registration, autowire, ResolveOption,
           RegistrationOption, existingInstance;

    import dango.system.container : registerNamed, resolveNamed;
}


/**
 * Компонент системы, который ассоциирован с именем
 */
interface Named
{
    /**
     * Возвращает имя компонента
     */
    string name() @property;
}


/**
 * Компонент системы, который содержит состояние активности
 */
interface Activated
{
    /**
     * Возвращает активность компонента
     */
    bool enabled() @property;

    /**
     * Установка активность компонента
     */
    void enabled(bool val) @property;
}


/**
 * Интерфейс фабрики для создания компонентов системы
 * I - конструируемый тип
 */
interface ComponentFactory(I)
    if (is(I == interface) || is (I == class))
{
    /**
     * Создает компонент на основе конфигов
     */
    I create(Properties config);
}


/**
 * Интерфейс фабрики для создания компонентов системы
 * I - конструируемый тип
 * T - тип для геренации конструкторов
 */
interface GenericComponentFactory(I, T : I) : ComponentFactory!I
    if (is(T == class))
{
    static if (__traits(compiles, __traits(getOverloads, T, `__ctor`)))
        static foreach (ctor; __traits(getOverloads, T, `__ctor`))
        {
            static if (!(Parameters!ctor.length == 1
                        && is(Parameters!ctor[0] == Properties)))
            {
                T create(Parameters!ctor);
            }
        }
    else
    {
        T create();
    }
}


/**
 * Класс фабрики для создания компонентов системы с использование DI
 * I - конструируемый тип
 * T - тип для геренации конструкторов
 */
class AutowireComponentFactory(I, T : I) : GenericComponentFactory!(I, T)
{
    protected ApplicationContainer container;

    static if (__traits(compiles, __traits(getOverloads, T, `__ctor`)))
        static foreach (ctor; __traits(getOverloads, T, `__ctor`))
        {
            static if (!(Parameters!ctor.length == 1
                        && is(Parameters!ctor[0] == Properties)))
            {
                T create(Parameters!ctor args)
                {
                    auto ret = new T(args);
                    container.autowire(ret);
                    return ret;
                }
            }
        }
    else
    {
        T create()
        {
            auto ret = new T();
            container.autowire(ret);
            return ret;
        }
    }


    this(ApplicationContainer container)
    {
        this.container = container;
    }


    T create(Properties config)
    {
        throw new Exception("Not implemented create using configuration");
    }


    /**
     * Регистрация фабрики компонента в контейнер
     * Params:
     * container = Контейнер DI
     * options   = Опции poodinis
     */
    static Registration registerComponent(F : AutowireComponentFactory!(I, T))(
            ApplicationContainer container, RegistrationOption options = RegistrationOption.none)
    {
        auto factory = new F(container);
        container.autowire(factory);
        container.register!(GenericComponentFactory!(I, T), F)
            .existingInstance(factory);

        static if (is(T : Named) && __traits(compiles, T.NAME))
            return container.registerNamed!(ComponentFactory!I, F, T.NAME)
                .existingInstance(factory);
        else
            return container.register!(ComponentFactory!I, F)
                .existingInstance(factory);
    }
}


/**
 * Класс фабрики для создания компонентов системы с простым вызовом конструкторов
 * T - конструируемый тип
 */
class SimpleComponentFactory(I, T : I) : GenericComponentFactory!(I, T)
{
    static if (__traits(compiles, __traits(getOverloads, T, `__ctor`)))
        static foreach (ctor; __traits(getOverloads, T, `__ctor`))
        {
            static if (!(Parameters!ctor.length == 1
                        && is(Parameters!ctor[0] == Properties)))
            {
                T create(Parameters!ctor args)
                {
                    return new T(args);
                }
            }
        }
    else
    {
        T create()
        {
            return new T();
        }
    }


    T create(Properties config)
    {
        throw new Exception("Not implemented create using configuration");
    }


    /**
     * Регистрация фабрики компонента в контейнер
     * Params:
     * container = Контейнер DI
     * options   = Опции poodinis
     */
    static Registration registerComponent(F : SimpleComponentFactory!(I, T))(
            ApplicationContainer container, RegistrationOption options = RegistrationOption.none)
    {
        container.register!(GenericComponentFactory!(I, T), F);
        static if (is(T : Named) && __traits(compiles, T.NAME))
            return container.registerNamed!(ComponentFactory!I, F, T.NAME);
        else
            return container.register!(ComponentFactory!I, F);
    }
}


/**
 * Регистрация фабрики компонентов в контейнер с простым функционалом создания новых компонент
 * Params:
 * container = Контейнер DI
 * options   = Опции poodinis
 */
Registration registerFactory(C, F : ComponentFactory!C)(ApplicationContainer container,
        RegistrationOption options = RegistrationOption.none)
{
    return F.registerComponent!(F)(container, options);
}


/**
 * Резолвинг компонента при помощи фабрики зарегистрированной в DI
 * Params:
 * container = Контейнер DI
 * options   = Опции poodinis
 */
ComponentFactory!C resolveFactory(C)(ApplicationContainer container,
        ResolveOption resolveOptions = ResolveOption.none)
{
    return container.resolve!(ComponentFactory!C)(resolveOptions);
}


/**
 * Резолвинг компонента при помощи фабрики зарегистрированной в DI
 * Params:
 * container = Контейнер DI
 * options   = Опции poodinis
 */
GenericComponentFactory!(I, T) resolveFactory(I, T : I)(ApplicationContainer container,
        ResolveOption resolveOptions = ResolveOption.none)
{
    return container.resolve!(GenericComponentFactory!(I, T))(resolveOptions);
}


/**
 * Резолвинг именованного компонента при помощи фабрики зарегистрированной в DI
 * Params:
 * container = Контейнер DI
 * options   = Опции poodinis
 */
ComponentFactory!C resolveFactory(C)(ApplicationContainer container, string name,
        ResolveOption resolveOptions = ResolveOption.none)
{
    return container.resolveNamed!(ComponentFactory!C)(name, resolveOptions);
}

