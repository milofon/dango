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
}


/**
 * Интерфейс фабрики для создания компонентов системы
 * T - конструируемый тип
 */
interface ComponentFactory(T) if (!is(T == struct))
{
    static if (__traits(compiles, __traits(getOverloads, T, `__ctor`)))
        static foreach (ctor; __traits(getOverloads, T, `__ctor`))
        {
            static if (Parameters!ctor.length > 1
                    || !is(Parameters!ctor[0] == Properties))
                T create(Parameters!ctor);
        }
    else
        T create();

    /**
     * Создает компонент на основе конфигов
     */
    T create(Properties config);
}


/**
 * Класс фабрики для создания компонентов системы с использование DI
 * T - конструируемый тип
 */
class AutowireComponentFactory(T) : ComponentFactory!T
{
    private ApplicationContainer _container;


    static if (__traits(compiles, __traits(getOverloads, T, `__ctor`)))
        static foreach (ctor; __traits(getOverloads, T, `__ctor`))
        {
            static if (Parameters!ctor.length > 1
                    || !is(Parameters!ctor[0] == Properties))
            {
                T create(Parameters!ctor args)
                {
                    auto ret = new T(args);
                    _container.autowire(ret);
                    return ret;
                }
            }
        }
    else
    {
        T create()
        {
            auto ret = new T();
            _container.autowire(ret);
            return ret;
        }
    }


    this(ApplicationContainer container)
    {
        this._container = container;
    }


    T create(Properties config)
    {
        return create();
    }


    /**
     * Регистрация фабрики компонента в контейнер
     * Params:
     * container = Контейнер DI
     * options   = Опции poodinis
     */
    static Registration registerComponent(F : AutowireComponentFactory!T)(
            ApplicationContainer container, RegistrationOption options = RegistrationOption.none)
    {
        auto factory = new F(container);
        container.autowire(factory);
        return container.register!(ComponentFactory!T, F)
            .existingInstance(factory);
    }
}


/**
 * Класс фабрики для создания компонентов системы с простым вызовом конструкторов
 * T - конструируемый тип
 */
class SimpleComponentFactory(T) : ComponentFactory!T
{
    static if (__traits(compiles, __traits(getOverloads, T, `__ctor`)))
        static foreach (ctor; __traits(getOverloads, T, `__ctor`))
        {
            static if (Parameters!ctor.length > 0
                    || !is(Parameters!ctor[0] == Properties))
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
        return create();
    }


    /**
     * Регистрация фабрики компонента в контейнер
     * Params:
     * container = Контейнер DI
     * options   = Опции poodinis
     */
    static Registration registerComponent(F : ComponentFactory!T)(
            ApplicationContainer container, RegistrationOption options = RegistrationOption.none)
    {
        return container.register!(ComponentFactory!T, F);
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
    return F.registerComponent!F(container, options);
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
    return container.resolve!(ComponentFactory!C);
}

