/**
 * Модуль работы с компонентами и фабриками к ним
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-26
 */

module dango.system.container.component;

private
{
    import std.traits : TemplateArgsOf, TransitiveBaseTypeTuple;
    import std.format : fmt = format;
    import std.meta : AliasSeq, staticIndexOf;

    import poodinis;

    import dango.system.container : registerNamed, resolveNamed,
           ApplicationContainer;
}


/**
 * Компонент системы, который ассоциирован с именем
 */
interface NamedComponent
{
    /**
     * Возвращает имя компонента
     */
    string name() @property;
}


/**
 * Компонент системы, который содержит состояние активности
 */
interface ActivatedComponent
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
mixin template NamedComponentMixin(string N)
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
mixin template ActivatedComponentMixin()
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



unittest
{
    class Component : NamedComponent, ActivatedComponent
    {
        mixin NamedComponentMixin!"TEST";
        mixin ActivatedComponentMixin!();
    }

    auto c = new Component();
    assert(c.name == "TEST");
    assert(c.enabled == false);
    c.enabled = true;
    assert(c.enabled == true);
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
    I createComponent(A args);
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
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 */
Registration factoryInstance(F : PreComponentFactory!(I, A), I, A...)(
        Registration registration, F factory,
        CreatesSingleton createSingleton = CreatesSingleton.yes)
{
    InstanceFactoryMethod method = () {
        return cast(Object)factory.create();
    };
    registration.instanceFactory = new InstanceFactory(registration.instanceType,
            createSingleton, null, method);
    return registration;
}



version(unittest)
{
    class Config
    {
        string host = "localhost";
    }


    interface IItem : NamedComponent
    {
        int val() @property;

        void val(int val) @property;

        string host() @property;
    }


    class Item : IItem
    {
        mixin NamedComponentMixin!"ITEM";
        @Autowire Config conf;
        private int _a;

        this(int a)
        {
            this._a = a;
        }

        int val() @property
        {
            return _a;
        }

        void val(int val) @property
        {
            _a = val;
        }

        string host() @property
        {
            return conf.host;
        }
    }


    class ItemFactory : ComponentFactory!(IItem, int)
    {
        IItem createComponent(int a)
        {
            return new Item(a);
        }
    }


    ApplicationContainer createContainer()
    {
        auto cnt = new ApplicationContainer();
        cnt.register!Config;
        return cnt;
    }
}


unittest
{
    class PreItemFactory : PreComponentFactory!(IItem, int)
    {
        private
        {
            ComponentFactory!(IItem, int) _factory;
            int _a;
        }


        this(ComponentFactory!(IItem, int) factory, int a)
        {
            this._factory = factory;
            this._a = a;
        }


        IItem create()
        {
            return _factory.createComponent(_a);
        }
    }


    auto cnt = createContainer();
    auto factory = new ItemFactory();
    cnt.register!(IItem, Item)
        .factoryInstance!PreItemFactory(new PreItemFactory(factory, 1));

    auto item = cnt.resolve!IItem;
    assert(item.name == "ITEM");
    assert(item.val == 1);
}


/**
 * Класс простой фабрики с возможностью создать объект
 * на основе преинициализированных данных.
 * Используется в DI
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
class SimplePreComponentFactory(I, A...)
        : PreComponentFactory!(I, A)
{
    private
    {
        ComponentFactory!(I, A) _factory;
        A _args;
    }


    this(ComponentFactory!(I, A) factory, A args)
    {
        this._factory = factory;
        this._args = args;
    }


    I create()
    {
        return _factory.createComponent(_args);
    }
}



unittest
{
    alias SF = SimplePreComponentFactory!(IItem, int);
    auto cnt = createContainer();
    auto factory = new ItemFactory();
    cnt.register!(IItem, Item)
        .factoryInstance!SF(new SF(factory, 1));

    auto item = cnt.resolve!IItem;
    assert(item.name == "ITEM");
    assert(item.val == 1);
    assert(item.host == "localhost");
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 * A = Типы аргументов
 */
Registration factoryInstance(F : ComponentFactory!(I), I, A...)(
        Registration registration, A args)
{
    auto factoryFunctor = new F();

    static if (A.length && is(A[0] == CreatesSingleton))
    {
        CreatesSingleton createSingleton = args[0];
        alias AR = A[1..$];
        AR arguments = args[1..$];
    }
    else
    {
        CreatesSingleton createSingleton = CreatesSingleton.yes;
        alias AR = A;
        AR arguments = args;
    }

    alias SF = SimplePreComponentFactory!(I, AR);

    alias PARENTS = TransitiveBaseTypeTuple!F;
    alias PIDX = staticIndexOf!(ComponentFactory!(I, AR), PARENTS);
    static assert (PIDX > -1, "Factory not ComponentFactory");
    alias FA = TemplateArgsOf!(PARENTS[PIDX]);

    static assert(is(FA[0] == I), "Component factory not " ~ FA[0].stringof);
    static foreach(i, TT; AR)
        static assert(is(FA[i+1] == TT),
            fmt!("Trying to factory %s but have %s.")(AR.stringof, FA[1..$].stringof));

    auto factory = new SF(factoryFunctor, arguments);
    return factoryInstance!SF(registration, factory, createSingleton);
}



unittest
{
    auto cnt = createContainer();

    cnt.register!(IItem, Item)
        .factoryInstance!ItemFactory(3);

    auto item = cnt.resolve!IItem;
    assert(item.name == "ITEM");
    assert(item.val == 3);

    item.val = 4;
    auto item2 = cnt.resolve!IItem;
    assert(item2.name == "ITEM");
    assert(item2.val == 4);
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
     * args   = Аргументы
     */
    I create(A args);
}


/**
 * Класс фабрики с возможностью создать объект
 * на основе переданных параметров с резолвингом зависимостей через DI
 * Params:
 * I - Конструируемый тип
 * T = Реализация компонента
 * A - Типы аргументов
 */
class AutowirePostComponentFactory(I, T : I, A...)
    : PostComponentFactory!(I, A)
{
    private
    {
        ComponentFactory!(I, A) _factory;
        ApplicationContainer _container;
    }


    this(ApplicationContainer container, ComponentFactory!(I, A) factory)
    {
        this._container = container;
        this._factory = factory;
    }


    I create(A args)
    {
        auto ret = cast(T)_factory.createComponent(args);
        _container.autowire!T(ret);
        return ret;
    }
}



unittest
{
    auto cnt = createContainer();
    auto factory = new ItemFactory();

    alias AF = AutowirePostComponentFactory!(IItem, Item, int);
    auto f = new AF(cnt, factory);

    auto item = f.create(2);
    assert(item.name == "ITEM");
    assert(item.val == 2);
    assert(item.host == "localhost");
}


/**
 * Регистрация фабрики компонентов в контейнер
 * Params:
 * I = Интерфес компонента
 * T = Реализация компонента
 * F = Фабрика компонента
 * A = Типы аргументов
 */
Registration registerFactory(F : ComponentFactory!(I, A), T : I, I, A...)(
        ApplicationContainer container, F factoryFunctor,
        RegistrationOption options = RegistrationOption.none)
{
    alias IAF = PostComponentFactory!(I, A);
    alias AF = AutowirePostComponentFactory!(I, T, A);
    auto factory = new AF(container, factoryFunctor);

    static if (is(T : NamedComponent) && __traits(compiles, T.NAME))
    {
        return container.registerNamed!(IAF, AF, T.NAME)(options)
            .existingInstance(factory);
    }
    else
    {
        return container.register!(IAF, AF)
            .existingInstance(factory);
    }
}



unittest
{
    auto cnt = createContainer();
    auto f = new ItemFactory();
    cnt.registerFactory!(ItemFactory, Item)(f);
    auto af = cnt.resolve!(PostComponentFactory!(IItem, int));

    auto item = af.create(22);
    assert(item.name == "ITEM");
    assert(item.val == 22);
    assert(item.host == "localhost");
}


/**
 * Регистрация фабрики компонентов в контейнер
 * Params:
 * I = Интерфес компонента
 * T = Реализация компонента
 * F = Фабрика компонента
 * A = Типы аргументов
 */
Registration registerFactory(F : ComponentFactory!(I, A), T : I, I, A...)(
        ApplicationContainer container,
        RegistrationOption options = RegistrationOption.none)
{
    auto factoryFunctor = new F();
    container.autowire(factoryFunctor);
    return registerFactory!(F, T, I, A)(container, factoryFunctor, options);
}



unittest
{
    auto cnt = createContainer();
    cnt.registerFactory!(ItemFactory, Item)();
    auto af = cnt.resolve!(PostComponentFactory!(IItem, int));

    auto item = af.create(22);
    assert(item.name == "ITEM");
    assert(item.val == 22);
    assert(item.host == "localhost");
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



unittest
{
    auto cnt = createContainer();
    cnt.registerFactory!(ItemFactory, Item)();
    auto af = cnt.resolveFactory!(IItem, int);

    auto item = af.create(22);
    assert(item.name == "ITEM");
    assert(item.val == 22);
    assert(item.host == "localhost");
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



unittest
{
    auto cnt = createContainer();
    cnt.registerFactory!(ItemFactory, Item)();
    auto af = cnt.resolveFactory!(IItem, int)("item");

    auto item = af.create(22);
    assert(item.name == "ITEM");
    assert(item.val == 22);
    assert(item.host == "localhost");
}

