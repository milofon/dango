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
    import std.traits : TemplateArgsOf, TransitiveBaseTypeTuple,
           hasMember, TemplateOf;
    import std.format : fmt = format;
    import std.functional : toDelegate;
    import std.meta : AliasSeq, staticIndexOf, Filter;

    import bolts : isFunctionOver;
    import poodinis;

    import dango.system.container.exception;
    import dango.system.container.named : registerNamed, resolveNamed;
}


/**
 * Интерфейс фабрики для создания компонентов системы
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
interface ComponentFactory(C, A...)
{
    alias ComponentType = C;

    /**
     * Создает компонент на основе конфигов
     */
    C createComponent(A args);
}



version (unittest)
{
    class StringValueInjector : ValueInjector!string
    {
        private string _prefix;


        this(string prefix)
        {
            this._prefix = prefix;
        }


        string get(string key)
        {
            return _prefix ~ key;
        }
    }


    interface IItem
    {
        string key() @property const;

        double value() @property const;

        void value(double val) @property;

        string prefix() @property const;
    }


    class Item : IItem
    {
        private string _key;
        private double _value;

        @Value("item")
        string _prefix;

        this()
        {
            this._key = "empty";
            this._value = 5.5;
        }

        this(string key, double val)
        {
            this._key = key;
            this._value = val;
        }

        string key() @property const
        {
            return _key;
        }

        double value() @property const
        {
            return _value;
        }

        void value(double val) @property
        {
            this._value = val;
        }

        string prefix() @property const
        {
            return _prefix;
        }

        override string toString() const
        {
            return fmt!("{%s: %s}")(_key, _value);
        }
    }


    class TestFactory : ComponentFactory!(Item, string, double)
    {
        Item createComponent(string key, double val)
        {
            return new Item(key, val);
        }
    }


    class EmptyFactory : ComponentFactory!(Item)
    {
        Item createComponent()
        {
            return new Item("empty", 1.0);
        }
    }


    shared(DependencyContainer) createContainer()
    {
        auto cnt = new shared(DependencyContainer)();
        cnt.register!(ValueInjector!string, StringValueInjector)
            .existingInstance(new StringValueInjector("super "));
        return cnt;
    }
}



@system unittest
{
    auto factory = new TestFactory();
    assert(is(factory.ComponentType == Item));
}


/**
 * Интерфейс фабрики с возможностью создать объект
 * на основе преинициализированных данных, так и без них.
 *
 * Params:
 * T - Конструируемый тип
 */
interface ComponentFactoryAdapter(ST)
{
    private template ByTypeId(D)
    {
        enum ByTypeId = typeid(D);
    }


    private interface Functor
    {
        ST execute() const;

        TypeInfo[] getInfoArgs() const;

        bool initialized() @property const;

        void autowireVisit(shared(DependencyContainer) container, ST instance) const;
    }


    private interface FunctorArgs(A...) : Functor
    {
        ST execute(A args);
    }


    const(Functor) functor() @property const;


    /**
     * Создает компонент
     */
    final ST create(A...)(A args)
    {
        if (functor is null)
            throw new DangoComponentException("Factory not initialized");

        if (args.length == functor.getInfoArgs.length)
        {
            auto functorArgs = cast(FunctorArgs!A)functor;
            if (functorArgs is null)
            {
                throw new Exception(fmt!"Error creating object, use arguments %s"(
                            functor.getInfoArgs()));
            }
            return functorArgs.execute(args);
        }
        else
            return functor.execute();
    }


    bool initialized() @property const;


    private final void autowire(shared(DependencyContainer) container, ST instance)
    {
        if (functor is null)
            throw new DangoComponentException("Factory not initialized");

        functor.autowireVisit(container, instance);
    }


    private static ComponentFactoryAdapterImpl!ST opCall(F : ComponentFactory!(T), T, A...)(
            F cFactory, A argsInit) if (is(T : ST))
    {
        import std.meta : staticMap;
        enum IsComponentFactory(CF) = __traits(isSame, TemplateOf!CF, ComponentFactory);

        alias PARENTS = Filter!(IsComponentFactory, TransitiveBaseTypeTuple!F);
        static assert (PARENTS.length, "Factory not ComponentFactory");
        alias FA = TemplateArgsOf!(PARENTS[0]);

        static assert(is(FA[0] == T), "Component factory not " ~ FA[0].stringof);

        template FunctorArgsMixin()
        {
            final TypeInfo[] getInfoArgs() const
            {
                return [staticMap!(ByTypeId, FAI)];
            }

            void autowireVisit(shared(DependencyContainer) container, ST instance) const
            {
                container.autowire!T(cast(T)instance);
            }

            bool initialized() @property const
            {
                static if (FA.length == 1U || (FA.length - 1U) == A.length)
                    return true;
                else
                    return false;
            }
        }

        static if (FA.length == 1) // если фабрика не принимает аргументов
        {
            static assert (A.length == 0, "Factory " ~ F.stringof ~ " takes no arguments");
            alias FAI = A;

            class FunctorArgsImpl : FunctorArgs!FAI
            {
                mixin FunctorArgsMixin!();

                T execute() const
                {
                    return cFactory.createComponent();
                }
            }
        }
        else static if ((FA.length - 1U) == A.length) // если переданы аргументы
        {
            static foreach(i, TT; A)
                static assert(is(FA[i+1] == TT),
                    fmt!("Trying to factory %s but have %s.")(A.stringof,
                        FA[1..$].stringof));
            alias FAI = A;

            class FunctorArgsImpl : FunctorArgs!FAI
            {
                mixin FunctorArgsMixin!();

                T execute(FAI args) const
                {
                    return cFactory.createComponent(args);
                }

                T execute() const
                {
                    return cFactory.createComponent(argsInit);
                }
            }
        }
        else // если аргументов не передано
        {
            alias FAI = FA[1..$];

            class FunctorArgsImpl : FunctorArgs!FAI
            {
                mixin FunctorArgsMixin!();

                T execute() const
                {
                    throw new DangoComponentException(
                            fmt!"Error creating object, use arguments %s"(getInfoArgs()));
                }

                T execute(FAI args) const
                {
                    return cFactory.createComponent(args);
                }
            }
        }

        return new ComponentFactoryAdapterImpl!ST(new FunctorArgsImpl());
    }
}


/**
 * Реализация фабрики с возможностью создать объект
 * на основе преинициализированных данных, так и без них
 *
 * Params:
 * T   = Конструируемый тип
 * ST  = Предок типа
 */
private final class ComponentFactoryAdapterImpl(T) : ComponentFactoryAdapter!T
{

    private const(Functor) _factoryFunctor;

    this(Functor functor)
    {
        this._factoryFunctor = cast(const)functor;
    }


    const(Functor) functor() @property const
    {
        return _factoryFunctor;
    }


    bool initialized() @property const
    {
        return (_factoryFunctor !is null) && _factoryFunctor.initialized;
    }
}



@system unittest
{
    auto factory = new TestFactory();
    auto emptyFactory = new EmptyFactory();

    auto wFactory = ComponentFactoryAdapter!(IItem)(factory, "a", 1.1);

    assert (wFactory.initialized);
    IItem item = wFactory.create("s", 1.2);
    assert (item);
    assert (item.key == "s");
    assert (item.value == 1.2);

    item = wFactory.create();
    assert (item);
    assert (item.key == "a");
    assert (item.value == 1.1);

    auto eFactory = ComponentFactoryAdapter!IItem(emptyFactory);
    assert (eFactory.initialized);
    item = eFactory.create();
    assert (item);

    assert (item.key == "empty");
    assert (item.value == 1.0);

    item = eFactory.create("no", 4.5);
    assert (item);
    assert (item.key == "empty");
    assert (item.value == 1.0);

    auto aFactory = ComponentFactoryAdapter!IItem(factory);
    assert (!aFactory.initialized);

    item = aFactory.create("b", 4.4);
    assert (item);
    assert (item.key == "b");
    assert (item.value == 4.4);

    import std.exception : assertThrown;
    assertThrown!DangoComponentException(aFactory.create());
}



/**
 * Метод позволяет создавать компоненты на основе анализа конструкторов
 * Params:
 * C = Тип создаваемого объекта
 * args = Принимаемые аргументы
 */
private C createComponentByCtor(C, A...)(A args)
{
    enum hasValidCtor(alias ctor) = isFunctionOver!(ctor, args);

    static if (hasMember!(C, "__ctor"))
    {
        alias pCtors = Filter!(hasValidCtor,
                __traits(getOverloads, C, "__ctor"));
        static if(pCtors.length)
            return new C(args);
        else static if (!A.length)
            return new C();
        else
            static assert(false, fmt!"Component %s is not create using argument types (%s)"(
                    C.stringof, A.stringof));
    }
    else
        return new C();
}



@system unittest
{
    auto item = createComponentByCtor!(Item)("key", 3);
    assert (item);
    assert (item.key == "key");
    assert (item.value == 3);

    item = createComponentByCtor!(Item)();
    assert (item);
    assert (item.key == "empty");
    assert (item.value == 5.5);
}



/**
 * Фабрика автосгенерирована на основе конструктора компонента
 * Params:
 * I = Компонент
 * A = Аргументы
 */
class ComponentFactoryCtor(I, A...) : ComponentFactory!(I, A)
{
    /**
     * See_Also: ComponentFactory.createComponent
     */
    I createComponent(A args)
    {
        return createComponentByCtor!(I, A)(args);
    }
}



@system unittest
{
    auto factory = new ComponentFactoryCtor!(Item, string, double)();
    auto item = factory.createComponent("key", 3);
    assert (item);
    assert (item.key == "key");
    assert (item.value == 3);
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 */
private Registration factoryAdapterInstance(F : ComponentFactoryAdapter!(I), I)(
        Registration registration, F factory)
{
    if (!factory.initialized)
        throw new DangoComponentException(fmt!"Factory %s not initialized"(factory));

    InstanceFactoryMethod method = ()
    {
        return cast(Object)factory.create();
    };

    auto createSingleton = registration.instanceFactory.factoryParameters.createsSingleton;
    registration.instanceFactory.factoryParameters = InstanceFactoryParameters(
        registration.instanceType, createSingleton, null, method);
    return registration;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();
    auto wFactory = ComponentFactoryAdapter!Item(factory, "a", 1.1);

    auto reg = cnt.register!(Item).factoryAdapterInstance(wFactory);
    assert(reg);
    auto item = cnt.resolve!Item;
    assert (item);
    assert (item.key == "a");
    assert (item.value == 1.1);
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 */
Registration factoryInstance(F : ComponentFactory!(I, A), I, A...)(
        Registration registration, F factory, A args)
{
    auto wFactory = ComponentFactoryAdapter!I(factory, args);
    return registration.factoryAdapterInstance(wFactory);
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();

    auto reg = cnt.registerNamed!(Item, "one").factoryInstance(factory, "b", 6.5);
    assert(reg);
    auto item = cnt.resolveNamed!Item("one");
    assert (item);
    assert (item.key == "b");
    assert (item.value == 6.5);
}


/**
 * Регистрация компонента в контейнере DI
 * с возможностью создавать компонент при помощи фабрики
 *
 * Params:
 * F = Тип фабрики для создания компонента
 * P = Родительский тип для создаваемого компонента
 * I = Тип создаваемого компонента
 * A = Аргументы передаваемые в фабрику
 */
Registration registerComponent(P, F : ComponentFactory!(I), I : P, A...)(
        shared(DependencyContainer) container, F factory, A args)
{
    auto wFactory = ComponentFactoryAdapter!P(factory, args);
    auto ret = container.register!(ComponentFactoryAdapter!P, ComponentFactoryAdapterImpl!P)
        .existingInstance(wFactory);
    if (wFactory.initialized)
        container.register!(P, I).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();

    auto reg = cnt.registerComponent!(IItem, TestFactory)(factory, "c", 7.3);
    assert(reg);

    auto item = cnt.resolve!IItem();
    assert (item);
    assert (item.key == "c");
    assert (item.value == 7.3);

    auto itemFact = cnt.resolve!(ComponentFactoryAdapter!IItem);
    assert(itemFact);
    item = itemFact.create();
    assert (item);
    assert (item.key == "c");
    assert (item.value == 7.3);
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();
    auto reg = cnt.registerComponent!(IItem, TestFactory)(factory);
    assert(reg);

    import std.exception : assertThrown;
    assertThrown!ResolveException(cnt.resolve!IItem);

    auto itemFact = cnt.resolve!(ComponentFactoryAdapter!IItem);
    assert(itemFact);

    auto item = itemFact.create("dd", 5.3);
    assert (item);
    assert (item.key == "dd");
    assert (item.value == 5.3);

    assertThrown!DangoComponentException(itemFact.create());
}


/**
 * Регистрация компонента в контейнере DI с использованием имени
 * с возможностью создавать компонент при помощи фабрики
 *
 * Params:
 * F    = Тип фабрики для создания компонента
 * P    = Родительский тип для создаваемого компонента
 * Name = Имя компонента
 * I    = Тип создаваемого компонента
 * A    = Аргументы передаваемые в фабрику
 */
Registration registerNamedComponent(P, F : ComponentFactory!(I), string Name, I : P, A...)(
        shared(DependencyContainer) container, F factory, A args)
{
    auto wFactory = ComponentFactoryAdapter!P(factory, args);
    auto ret = container.registerNamed!(ComponentFactoryAdapter!P,
            ComponentFactoryAdapterImpl!P, Name).existingInstance(wFactory);
    if (wFactory.initialized)
        container.registerNamed!(P, I, Name).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();
    auto reg = cnt.registerNamedComponent!(IItem, TestFactory, "two")(factory, "d", 7.4);
    assert(reg);

    auto item = cnt.resolveNamed!IItem("two");
    assert (item);
    assert (item.key == "d");
    assert (item.value == 7.4);

    auto itemFact = cnt.resolveNamed!(ComponentFactoryAdapter!IItem)("two");
    assert(itemFact);

    item = itemFact.create("dd", 5.3);
    assert (item);
    assert (item.key == "dd");
    assert (item.value == 5.3);
}


/**
 * Резолвинг компонента с использованием фабрики для указанного компонента
 * Params:
 * container = Контейнер DI
 * args      = Параметры
 */
RegistrationType resolveComponent(RegistrationType, A...)(
        shared(DependencyContainer) container, A args)
{
    auto factory = container.resolve!(ComponentFactoryAdapter!RegistrationType);
    auto ret = factory.create(args);
    factory.autowire(container, ret);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();
    auto reg = cnt.registerComponent!(IItem, TestFactory)(factory, "c", 7.3);
    assert(reg);

    auto item = cnt.resolveComponent!IItem("r", 2.2);
    assert (item);
    assert (item.key == "r");
    assert (item.value == 2.2);
    assert (item.prefix == "super item");
}


/**
 * Резолвинг компонента с использованием фабрики для указанного компонента.
 * Именованный компонент
 * Params:
 * container = Контейнер DI
 * args      = Параметры
 */
RegistrationType resolveNamedComponent(RegistrationType, A...)(
        shared(DependencyContainer) container, string name, A args)
{
    auto factory = container.resolveNamed!(ComponentFactoryAdapter!RegistrationType)(name);
    auto ret = factory.create(args);
    factory.autowire(container, ret);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();
    auto reg = cnt.registerNamedComponent!(IItem, TestFactory, "four")(factory, "c", 7.3);
    assert(reg);

    auto item = cnt.resolveNamedComponent!IItem("four", "t", 4.4);
    assert (item);
    assert (item.key == "t");
    assert (item.value == 4.4);
    assert (item.prefix == "super item");
}


/**
 * Регистрация компонента в контейнере DI с использованием
 * фабрики задействующей конструкторы компонента
 *
 * Params:
 * SuperType    = Родительский тип для создаваемого компонента
 * ConcreteType = Тип компонента
 * A            = Аргументы передаваемые в фабрику
 */
Registration registerComponent(SuperType, ConcreteType : SuperType, A...)(
        shared(DependencyContainer) container, A args)
{
    alias F = ComponentFactoryCtor!(ConcreteType, A);
    return registerComponent!(SuperType, F, ConcreteType, A)(container, new F(), args);
}



@system unittest
{
    auto cnt = createContainer();
    auto reg = cnt.registerComponent!(IItem, Item)("e", 9.1);
    assert(reg);

    auto item = cnt.resolveComponent!IItem();
    assert (item);
    assert (item.key == "e");
    assert (item.value == 9.1);
    assert (item.prefix == "super item");
}


/**
 * Регистрация именованного компонента в контейнере DI с использованием
 * фабрики задействующей конструкторы компонента
 *
 * Params:
 * SuperType    = Родительский тип для создаваемого компонента
 * ConcreteType = Тип компонента
 * Name         = Имя компонента
 * A            = Аргументы передаваемые в фабрику
 */
Registration registerNamedComponent(SuperType, ConcreteType : SuperType, string Name, A...)(
        shared(DependencyContainer) container, A args)
{
    alias F = ComponentFactoryCtor!(ConcreteType, A);
    return registerNamedComponent!(SuperType, F, Name, ConcreteType, A)(container,
            new F(), args);
}



@system unittest
{
    auto cnt = createContainer();

    auto reg = cnt.registerNamedComponent!(IItem, Item, "four")("f", 56.1);
    assert(reg);

    auto item = cnt.resolveNamedComponent!IItem("four");
    assert (item);
    assert (item.key == "f");
    assert (item.value == 56.1);
    assert (item.prefix == "super item");
}


/**
 * Компонент системы, который ассоциирован с именем
 */
interface NamedComponent
{
    /**
     * Возвращает имя компонента
     */
    string name() @property const;
}


/**
 * Компонент системы, который содержит состояние активности
 */
interface ActivatedComponent
{
    /**
     * Возвращает активность компонента
     */
    bool enabled() @property const;

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

    string name() @property const
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


    bool enabled() @property const
    {
        return _enabled;
    }


    void enabled(bool val) @property
    {
        _enabled = val;
    }
}



@system unittest
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



@system unittest
{
    auto cnt = createContainer();
    auto factory = new TestFactory();

    cnt.register!(IItem, Item)
        .factoryInstance(factory, "ITEM", 6.6);

    auto item = cnt.resolve!IItem;
    assert(item.key == "ITEM");
    assert(item.value == 6.6);

    item.value = 4.4;
    auto item2 = cnt.resolve!IItem;
    assert(item2.key == "ITEM");
    assert(item2.value == 4.4);
}

