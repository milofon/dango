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
    import std.exception : assertThrown;

    class CheckValueInjector : ValueInjector!int
    {
        private int[string] _dict;

        this()
        {
            this._dict = ["item": 1, "single": 2];
        }

        int get(string key)
        {
            return _dict[key];
        }
    }


    interface IItem
    {
        void value(double val) @property;

        bool verify(string k, double v, int chk);
    }


    class Item : IItem
    {
        private string _key;
        private double _value;

        @Value("item")
        int _chk;

        this(string key, double val)
        {
            this._key = key;
            this._value = val;
        }

        void value(double val) @property
        {
            this._value = val;
        }

        override string toString() const
        {
            return fmt!("{%s, %s, %s}")(_key, _value, _chk);
        }

        bool verify(string k, double v, int chk)
        {
            bool ret = (k == _key) && (v == _value) && (chk == _chk);
            if (!ret)
            {
                import std.stdio: wl = writeln;
                wl(_key, " = ", k, ", ", _value, " = ", v, ", ", _chk, " = ", chk);
            }
            return ret;
        }
    }


    class ItemSingle
    {
        private string _key;
        private double _value;

        @Value("single")
        int _chk;

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

        void value(double val) @property
        {
            this._value = val;
        }

        override string toString() const
        {
            return fmt!("{%s, %s, %s}")(_key, _value, _chk);
        }

        bool verify(string k, double v, int chk)
        {
            bool ret = (k == _key) && (v == _value) && (chk == _chk);
            if (!ret)
            {
                import std.stdio: wl = writeln;
                wl(_key, " = ", k, ", ", _value, " = ", v, ", ", _chk, " = ", chk);
            }
            return ret;
        }
    }


    class IItemFactory : ComponentFactory!(IItem, string, double)
    {
        Item createComponent(string key, double val)
        {
            return new Item(key, val);
        }
    }


    class ItemFactory : ComponentFactory!(Item, string, double)
    {
        Item createComponent(string key, double val)
        {
            return new Item(key, val);
        }
    }


    class IItemEmptyFactory : ComponentFactory!(IItem)
    {
        Item createComponent()
        {
            return new Item("empty", 1.0);
        }
    }


    class ItemSingleFactory : ComponentFactory!(ItemSingle, string, double)
    {
        ItemSingle createComponent(string key, double val)
        {
            return new ItemSingle(key, val);
        }
    }


    class DepthItemFactory : ItemFactory
    {
        override Item createComponent(string key, double val)
        {
            return super.createComponent("*" ~ key ~ "*", val * 2);
        }
    }


    shared(DependencyContainer) createContainer()
    {
        auto cnt = new shared(DependencyContainer)();
        cnt.register!(ValueInjector!int, CheckValueInjector);
        return cnt;
    }
}



@system unittest
{
    auto factory = new IItemFactory();
    assert(is(factory.ComponentType == IItem));

    auto factory2 = new ItemFactory();
    assert(is(factory2.ComponentType == Item));

    auto factory3 = new ItemSingleFactory();
    assert(is(factory3.ComponentType == ItemSingle));

    auto factory4 = new DepthItemFactory();
    assert(is(factory4.ComponentType == Item));
}


/**
 * Интерфейс фабрики с возможностью создать объект
 * на основе преинициализированных данных, так и без них.
 *
 * Params:
 * T - Конструируемый тип
 */
interface ComponentFactoryAdapter(T)
{
    private
    {
        interface Functor
        {
            T execute() const;

            TypeInfo[] getInfoArgs() const;

            bool initialized() @property const;
        }


        interface FunctorArgs(A...) : Functor
        {
            T execute(A args);
        }
    }

    /**
     * Создает компонент
     */
    final T create(A...)(A args)
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


    const(Functor) functor() @property const;


    bool initialized() @property const;


    void autowire(shared(DependencyContainer) container, T instance);
}


/**
 * Реализация фабрики с возможностью создать объект
 * на основе преинициализированных данных, так и без них
 *
 * Params:
 * T   = Конструируемый фабрикой тип
 * CT  = Текущий тип (необходим для резолвинга зависимостей)
 */
private final class ComponentFactoryAdapterImpl(T, CT : T) : ComponentFactoryAdapter!T
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


    void autowire(shared(DependencyContainer) container, T instance)
    {
        static if (__traits(compiles, container.autowire!CT(cast(CT)instance)))
            container.autowire!CT(cast(CT)instance);
    }


    bool initialized() @property const
    {
        return (_factoryFunctor !is null) && _factoryFunctor.initialized;
    }
}

/**
 * Создает адаптер над фабрикой компонента
 *
 * Params:
 * CT = Конктретный тип (необходим для резолвина зависимостей)
 * F  = Тип фабрики
 * T  = Тип возвращаемого фабрикой компонента
 * A  = Параметры метода создания компонента
 */
private ComponentFactoryAdapterImpl!(T, CT) createFactoryAdapter(CT, F : ComponentFactory!(T), T, A...)(
        F componentFactory, A argsInit) if (is(CT : T))
{
    import std.meta : staticMap;

    enum IsComponentFactory(CF) = __traits(isSame, TemplateOf!CF, ComponentFactory);

    template ByTypeId(D)
    {
        enum ByTypeId = typeid(D);
    }

    template FunctorArgsMixin()
    {
        final TypeInfo[] getInfoArgs() const
        {
            return [staticMap!(ByTypeId, FAI)];
        }

        bool initialized() @property const
        {
            static if (FA.length == 1U || (FA.length - 1U) == A.length)
                return true;
            else
                return false;
        }
    }

    alias Functor = ComponentFactoryAdapter!T.FunctorArgs;
    alias PARENTS = Filter!(IsComponentFactory, TransitiveBaseTypeTuple!F);
    static assert (PARENTS.length, "Factory not ComponentFactory");
    alias FA = TemplateArgsOf!(PARENTS[0]);

    static assert(is(T == FA[0]), "Component factory not " ~ FA[0].stringof);

    static if (FA.length == 1) // если фабрика не принимает аргументов
    {
        static assert (A.length == 0, "Factory " ~ F.stringof ~ " takes no arguments");
        alias FAI = A;

        class FunctorArgsImpl : Functor!FAI
        {
            mixin FunctorArgsMixin!();

            T execute() const
            {
                return componentFactory.createComponent();
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

        class FunctorArgsImpl : Functor!FAI
        {
            mixin FunctorArgsMixin!();

            T execute(FAI args) const
            {
                return componentFactory.createComponent(args);
            }

            T execute() const
            {
                return componentFactory.createComponent(argsInit);
            }
        }
    }
    else // если аргументов не передано
    {
        alias FAI = FA[1..$];

        class FunctorArgsImpl : Functor!FAI
        {
            mixin FunctorArgsMixin!();

            T execute() const
            {
                throw new DangoComponentException(
                        fmt!"Error creating object, use arguments %s"(getInfoArgs()));
            }

            T execute(FAI args) const
            {
                return componentFactory.createComponent(args);
            }
        }
    }

    return new ComponentFactoryAdapterImpl!(T, CT)(new FunctorArgsImpl);
}



@system unittest
{
    auto wFactory = createFactoryAdapter!(Item)(new DepthItemFactory(), "a", 1.1);
    assert (wFactory);
    assert (wFactory.initialized);
    assert (wFactory.create().verify("*a*", 2.2, 0));
    assert (wFactory.create("s", 1.2).verify("*s*", 2.4, 0));

    auto eFactory = createFactoryAdapter!(IItem)(new IItemEmptyFactory());
    assert (eFactory);
    assert (eFactory.initialized);
    assert (eFactory.create().verify("empty", 1.0, 0));
    assert (eFactory.create("s", 1.2).verify("empty", 1.0, 0));


    auto aFactory = createFactoryAdapter!(Item)(new ItemFactory());
    assert (!aFactory.initialized);
    assert (aFactory.create("b", 4.4).verify("b", 4.4, 0));

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
    assert (item.verify("key", 3, 0));

    auto sitem = createComponentByCtor!(ItemSingle)();
    assert (sitem.verify("empty", 5.5, 0));
}


/**
 * Фабрика автосгенерирована на основе конструктора компонента
 * Params:
 * I = Компонент
 * A = Аргументы
 */
class ComponentFactoryCtor(T, CT : T, A...) : ComponentFactory!(T, A)
{
    /**
     * See_Also: ComponentFactory.createComponent
     */
    T createComponent(A args)
    {
        return createComponentByCtor!(CT, A)(args);
    }
}



@system unittest
{
    auto factory = new ComponentFactoryCtor!(Item, Item, string, double)();
    auto item = factory.createComponent("key", 3);
    assert (item.verify("key", 3, 0));
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
    auto factory = new ItemFactory();
    auto wFactory = createFactoryAdapter!Item(factory, "a", 1.1);

    auto reg = cnt.register!(IItem, Item).factoryAdapterInstance(wFactory);
    assert(reg);
    auto item = cnt.resolve!IItem;
    assert (item.verify("a", 1.1, 1));
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 */
Registration factoryInstance(CT, F : ComponentFactory!(I, A), I, A...)(
        Registration registration, F factory, A args) if (is(CT : I))
{
    auto wFactory = createFactoryAdapter!CT(factory, args);
    return registration.factoryAdapterInstance(wFactory);
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new ItemFactory();

    auto reg = cnt.registerNamed!(Item, "one")
        .factoryInstance!Item(factory, "b", 6.5);
    assert(reg);
    auto item = cnt.resolveNamed!Item("one");
    assert (item.verify("b", 6.5, 1));
}


/**
 * Регистрация компонента в контейнере DI
 * с возможностью создавать компонент при помощи фабрики
 *
 * Params:
 * C =
 * F = Тип фабрики для создания компонента
 * P = Родительский тип для создаваемого компонента
 * I = Тип создаваемого компонента
 * A = Аргументы передаваемые в фабрику
 */
Registration registerComponent(CT, F : ComponentFactory!(T), T, A...)(
        shared(DependencyContainer) container, F factory, A args) if (is (CT : T))
{
    auto wFactory = createFactoryAdapter!CT(factory, args);
    auto ret = container.register!(ComponentFactoryAdapter!T, ComponentFactoryAdapterImpl!(T, CT))
            .existingInstance(wFactory);
    if (wFactory.initialized)
        container.register!(T, CT).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new IItemFactory();
    auto reg = cnt.registerComponent!(Item)(factory, "c", 7.3);
    assert(reg);
    auto item = cnt.resolve!IItem();
    assert (item.verify("c", 7.3, 1));
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new DepthItemFactory();
    auto reg = cnt.registerComponent!(Item)(factory, "c", 2.3);
    assert(reg);

    auto item = cnt.resolve!Item();
    assert (item.verify("*c*", 4.6, 1));

    auto itemFact = cnt.resolve!(ComponentFactoryAdapter!Item);
    assert(itemFact);
    item = itemFact.create();
    assert (item.verify("*c*", 4.6, 0));
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new IItemFactory();
    auto reg = cnt.registerComponent!(Item)(factory);
    assert(reg);

    assertThrown!ResolveException(cnt.resolve!IItem);

    auto itemFact = cnt.resolve!(ComponentFactoryAdapter!IItem);
    assert(itemFact);

    auto item = itemFact.create("dd", 5.3);
    assert (item.verify("dd", 5.3, 0));

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
Registration registerNamedComponent(CT, string Name, F : ComponentFactory!(T), T, A...)(
        shared(DependencyContainer) container, F factory, A args) if (is(CT : T))
{
    auto wFactory = createFactoryAdapter!CT(factory, args);
    auto ret = container.registerNamed!(ComponentFactoryAdapter!T,
            ComponentFactoryAdapterImpl!(T, CT), Name).existingInstance(wFactory);
    if (wFactory.initialized)
        container.registerNamed!(T, CT, Name).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new IItemFactory();
    auto reg = cnt.registerNamedComponent!(Item, "two")(factory, "d", 7.4);
    assert(reg);

    auto item = cnt.resolveNamed!IItem("two");
    assert (item.verify("d", 7.4, 1));

    auto itemFact = cnt.resolveNamed!(ComponentFactoryAdapter!IItem)("two");
    assert(itemFact);
    item = itemFact.create("dd", 5.3);
    assert (item.verify("dd", 5.3, 0));
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
    auto factory = new IItemFactory();
    auto reg = cnt.registerComponent!(Item)(factory, "c", 7.3);
    assert(reg);

    auto item = cnt.resolveComponent!IItem("r", 2.2);
    assert (item.verify("r", 2.2, 1));
}


@system unittest
{
    auto cnt = createContainer();
    auto factory = new ItemSingleFactory();
    auto reg = cnt.registerComponent!(ItemSingle)(factory, "c", 7.3);
    assert(reg);

    auto item = cnt.resolveComponent!ItemSingle();
    assert (item.verify("c", 7.3, 2));
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
    auto factory = new IItemFactory();
    auto reg = cnt.registerNamedComponent!(Item, "four")(factory, "c", 7.3);
    assert(reg);

    auto item = cnt.resolveNamedComponent!IItem("four", "t", 4.4);
    assert (item.verify("t", 4.4, 1));
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
    alias F = ComponentFactoryCtor!(SuperType, ConcreteType, A);
    return registerComponent!(ConcreteType, F, SuperType, A)(container, new F(), args);
}



@system unittest
{
    auto cnt = createContainer();
    auto reg = cnt.registerComponent!(Item, Item)("e", 9.1);
    assert(reg);

    auto item = cnt.resolveComponent!Item();
    assert (item.verify("e", 9.1, 1));
    assertThrown!ResolveException(cnt.resolveComponent!IItem);

    reg = cnt.registerComponent!(IItem, Item)("ee", 9.2);
    assert(reg);
    auto iitem = cnt.resolveComponent!IItem();
    assert (iitem.verify("ee", 9.2, 1));
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
    alias F = ComponentFactoryCtor!(SuperType, ConcreteType, A);
    return registerNamedComponent!(ConcreteType, Name, F, SuperType, A)(container,
            new F(), args);
}



@system unittest
{
    auto cnt = createContainer();

    auto reg = cnt.registerNamedComponent!(IItem, Item, "four")("f", 56.1);
    assert(reg);

    auto item = cnt.resolveNamedComponent!IItem("four");
    assert (item.verify("f", 56.1, 1));
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
        shared(DependencyContainer) container)
{
    alias F = ComponentFactoryCtor!(SuperType, ConcreteType, A);
    return registerNamedComponent!(ConcreteType, Name, F, SuperType)(container,
            new F());
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new IItemFactory();

    auto reg = cnt.registerNamedComponent!(IItem, Item, "four", string, double)();
    assert(reg);

    assertThrown!DangoComponentException(cnt.resolveNamedComponent!IItem("four"));
    auto item = cnt.resolveNamedComponent!IItem("four", "f", 32.2);
    assert (item.verify("f", 32.2, 1));
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
    auto factory = new IItemFactory();

    cnt.register!(IItem, Item)
        .factoryInstance!Item(factory, "ITEM", 6.6);

    auto item = cnt.resolve!IItem;
    assert(item.verify("ITEM", 6.6, 1));

    item.value = 4.4;
    auto item2 = cnt.resolve!IItem;
    assert(item2.verify("ITEM", 4.4, 1));
}

