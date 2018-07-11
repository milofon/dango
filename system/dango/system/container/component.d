/**
 * Модуль работы с компонентами и фабриками к ним
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-26
 */

module dango.system.container.component;

public
{
    import proped : Properties;

    import dango.system.container : ApplicationContainer;
}

private
{
    import std.traits : Parameters;
    import std.meta : AliasSeq;

    import poodinis;

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
 * Миксин для добавления простого функционала именования компонента
 * Params:
 * N = Наименование компонента
 */
mixin template NamedMixin(string N)
{
    enum NAME = N;

    string name() @property
    {
        return NAME;
    }
}


/**
 * Миксин для добавления простого функционала активации компонента
 */
mixin template ActivatedMixin()
{
    private bool _enabled;

    bool enabled() @property
    {
        return _enabled;
    }


    void enabled(bool val) @property
    {
        _enabled = val;
    }
}


/**
 * Интерфейс фабрики для создания компонентов системы
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
interface ComponentFactory(I, A...)
{
    /**
     * Создает компонент на основе конфигов
     */
    I createComponent(Properties config, A args);
}


/**
 * Интерфейс фабрики для создания компонентов системы
 * с возможностью пост иниуиализации
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
interface InitializingFactory(I, A...)
{
    /**
     * Позволяет провести пост инициализаяю комопнента
     */
    I initializeComponent(I component, Properties config, A args);
}


/**
 * Интерфейс фабрики с возможностью создать объект
 * на основе преинициализированных данных.
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
interface PreComponentFactory(I, A...)
{
    /**
     * Создает компонент без передачи аргументов
     */
    I create();
}


/**
 * Класс простой фабрики с возможностью создать объект
 * на основе преинициализированных данных.
 * Используется в DI
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
class SimplePreComponentFactory(F : ComponentFactory!(I, A), I, A...)
    : PreComponentFactory!(I, A)
{
    private
    {
        F _factory;
        Properties _config;
        A _args;
    }


    this(F factory, Properties config, A args)
    {
        this._factory = factory;
        this._config = config;
        this._args = args;
    }


    I create()
    {
        return _factory.createComponent(_config, _args);
    }
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 */
Registration factoryInstance(F : PreComponentFactory!(I, A), I, A...)(
        Registration registration, CreatesSingleton createSingleton, F factory)
{
    InstanceFactoryMethod method = () {
        return cast(Object)factory.create();
    };
    registration.instanceFactory = new InstanceFactory(registration.instanceType,
            createSingleton, null, method);
    return registration;
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 * A = Типы аргументов
 */
Registration factoryInstance(F : ComponentFactory!(I, A), I, A...)(
        Registration registration, CreatesSingleton createSingleton, Properties config, A args)
{
    auto factoryFunctor = new F();
    container.autowire(factoryFunctor);
    auto factory = new SimplePreComponentFactory!(F, I, A)(factoryFunctor, config, args);

    return registration.factoryInstance!(PreComponentFactory!(I, A), I)(
            createSingleton, factory);
}


/**
 * Интерфейс фабрики с возможностью создать объект
 * на основе переданных параметров
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
interface PostComponentFactory(I, A...)
{
    /**
     * Создает компонент на основе передваемых аргументов
     * Params:
     * config = Конфигурация
     * args   = Аргументы
     */
    I create(Properties config, A args);
}


/**
 * Класс фабрики с возможностью создать объект
 * на основе переданных параметров с резолвингом зависимостей через DI
 * Params:
 * I - Конструируемый тип
 * T = Реализация компонента
 * A - Типы аргументов
 */
class AutowirePostComponentFactory(F : ComponentFactory!(I, A), I, T:I, A...)
    : PostComponentFactory!(I, A)
{
    private
    {
        F _factory;
        ApplicationContainer _container;
    }


    this(ApplicationContainer container, F factory)
    {
        this._container = container;
        this._factory = factory;
    }


    I create(Properties config, A args)
    {
        auto ret = cast(T)_factory.createComponent(config, args);
        static if (is (F : InitializingFactory!(I, A)))
            ret = cast(T)_factory.initializeComponent(ret, config, args);
        _container.autowire!T(ret);
        return ret;
    }
}


Registration registerFactory(F : ComponentFactory!(I, A), T:I, I, A...)(
        ApplicationContainer container, F factoryFunctor,
        RegistrationOption options = RegistrationOption.none)
{
    auto factory = new AutowirePostComponentFactory!(F, I, T, A)(container, factoryFunctor);
    static if (is(F : Named) && __traits(compiles, F.NAME))
        return container.registerNamed!(PostComponentFactory!(I, A),
                AutowirePostComponentFactory!(F, I, T, A), F.NAME)(options)
            .existingInstance(factory);
    else
        return container.register!(PostComponentFactory!(I, A),
                AutowirePostComponentFactory!(F, I, T, A))(options)
            .existingInstance(factory);
}

/**
 * Регистрация фабрики компонентов в контейнер
 * Params:
 * I = Интерфес компонента
 * T = Реализация компонента
 * F = Фабрика компонента
 * A = Типы аргументов
 */
Registration registerFactory(F : ComponentFactory!(I, A), T:I, I, A...)(
        ApplicationContainer container, RegistrationOption options = RegistrationOption.none)
{
    auto factoryFunctor = new F();
    container.autowire(factoryFunctor);
    return registerFactory!(F, T, I, A)(container, factoryFunctor, options);
}


/**
 * Резолвинг фабрики для указанного компонента
 * Params:
 * container = Контейнер DI
 * options   = Опции poodinis
 */
PostComponentFactory!(I, A) resolveFactory(I, A...)(ApplicationContainer container,
        ResolveOption resolveOptions = ResolveOption.none)
{
    return container.resolve!(PostComponentFactory!(I, A))(resolveOptions);
}


/**
 * Резолвинг фабрики для указанного именованного компонента
 * Params:
 * container = Контейнер DI
 * name      = Имя компонента
 * options   = Опции poodinis
 */
PostComponentFactory!(I, A) resolveFactory(I, A...)(ApplicationContainer container,
        string name, ResolveOption resolveOptions = ResolveOption.none)
{
    return container.resolveNamed!(PostComponentFactory!(I, A))(name, resolveOptions);
}

