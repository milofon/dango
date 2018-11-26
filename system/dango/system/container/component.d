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


    class Extruder
    {

    }


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
        @Value("item")
        int _chk;

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


    class CtorItemFactory : DepthItemFactory
    {
        @Autowire
        Extruder cfgMember;

        Extruder cfgCtor;

        @AutowireConstructor
        this(Extruder config)
        {
            cfgCtor = config;
        }

        override Item createComponent(string key, double val)
        {
            assert(cfgMember);
            assert(cfgCtor);
            return super.createComponent(key, val);
        }
    }


    shared(DependencyContainer) createContainer()
    {
        auto cnt = new shared(DependencyContainer)();
        cnt.register!(ValueInjector!int, CheckValueInjector);
        cnt.register!Extruder;
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
 * Интерфейс адаптера фабрики с возможностью создать объект
 * на основе преинициализированных данных, так и без них.
 *
 * Params:
 * T - Конструируемый тип
 */
interface ComponentFactoryAdapter(T)
{
    private
    {
        interface Wrapper
        {
            T execute() const;

            TypeInfo[] getInfoArgs() const;

            bool initialized() @property const;
        }


        interface WrapperArgs(A...) : Wrapper
        {
            T execute(A args);
        }
    }

    /**
     * Создает компонент
     */
    final T create(A...)(A args)
    {
        if (wrapper is null)
            throw new DangoComponentException("Factory not initialized");

        if (args.length == wrapper.getInfoArgs.length)
        {
            auto wrapperArgs = cast(WrapperArgs!A)wrapper;
            if (wrapperArgs is null)
            {
                throw new Exception(fmt!"Error creating object, use arguments %s"(
                            wrapper.getInfoArgs()));
            }
            return wrapperArgs.execute(args);
        }
        else
            return wrapper.execute();
    }

    /**
     * Возвращает обертку над аргументами
     */
    const(Wrapper) wrapper() @property;

    /**
     * Статус прединициализации
     */
    bool initialized() @property const;

    /**
     * Резолвинг зависимостей
     */
    void autowire(shared(DependencyContainer) container, T instance);
}


/**
 * Реализация адаптера фабрики с возможностью создать объект
 * на основе преинициализированных данных, так и без них.
 *
 * Params:
 * T - Конструируемый тип
 */
private class ComponentFactoryAdapterImpl(T) : ComponentFactoryAdapter!T
{
    private const(Wrapper) _factoryWrapper;


    this(const(Wrapper) wrapper)
    {
        this._factoryWrapper = wrapper;
    }


    const(Wrapper) wrapper() @property
    {
        return _factoryWrapper;
    }


    bool initialized() @property const
    {
        return (_factoryWrapper !is null) && _factoryWrapper.initialized;
    }


    void autowire(shared(DependencyContainer) container, T instance)
    {
        throw new DangoComponentException(fmt!"ComponentFactory %s not autowired"(
                    typeid(this)));
    }
}


/**
 * Реализация адаптера фабрики с возможностью создать объект
 * на основе преинициализированных данных, так и без них, с поддержкой autowire
 *
 * Params:
 * CT - Тип для autowire
 * T  - Конструируемый тип
 */
private class ComponentFactoryAdapterAutowired(T, CT : T) : ComponentFactoryAdapter!T
{
    private ComponentFactoryAdapter!T _adapter;


    this(ComponentFactoryAdapter!T adapter)
    {
        this._adapter = adapter;
    }


    const(Wrapper) wrapper() @property
    {
        return _adapter.wrapper;
    }


    override bool initialized() @property const
    {
        return _adapter.initialized();
    }


    void autowire(shared(DependencyContainer) container, T instance)
    {
        static if (__traits(compiles, container.autowire!CT(cast(CT)instance)))
            container.autowire!CT(cast(CT)instance);
    }
}


/**
 * Создает адаптер над фабрикой компонента
 * используя делегат для ленивого создания фабрики
 *
 * Params:
 * F  = Тип фабрики
 * T  = Тип возвращаемого фабрикой компонента
 * A  = Параметры метода создания компонента
 *
 * componentFactoryDelegate = Делегат для ленивого создания фабрики
 */
private ComponentFactoryAdapterImpl!(T) createFactoryAdapterDelegate(F : ComponentFactory!(T), T, A...)(
        F delegate() componentFactoryDelegate, A argsInit)
{
    import std.meta : staticMap;

    enum IsComponentFactory(CF) = __traits(isSame, TemplateOf!CF, ComponentFactory);

    template ByTypeId(D)
    {
        enum ByTypeId = typeid(D);
    }

    template WrapperArgsMixin()
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

    alias Wrapper = ComponentFactoryAdapter!T.WrapperArgs;
    alias PARENTS = Filter!(IsComponentFactory, TransitiveBaseTypeTuple!F);
    static assert (PARENTS.length, "Factory not ComponentFactory");
    alias FA = TemplateArgsOf!(PARENTS[0]);

    static assert(is(T == FA[0]), "Component factory not " ~ FA[0].stringof);

    static if (FA.length == 1) // если фабрика не принимает аргументов
    {
        static assert (A.length == 0, "Factory " ~ F.stringof ~ " takes no arguments");
        alias FAI = A;

        class WrapperArgsImpl : Wrapper!FAI
        {
            mixin WrapperArgsMixin!();

            T execute() const
            {
                return componentFactoryDelegate().createComponent();
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

        class WrapperArgsImpl : Wrapper!FAI
        {
            mixin WrapperArgsMixin!();

            T execute(FAI args) const
            {
                return componentFactoryDelegate().createComponent(args);
            }

            T execute() const
            {
                return componentFactoryDelegate().createComponent(argsInit);
            }
        }
    }
    else // если аргументов не передано
    {
        alias FAI = FA[1..$];

        class WrapperArgsImpl : Wrapper!FAI
        {
            mixin WrapperArgsMixin!();

            T execute() const
            {
                throw new DangoComponentException(
                        fmt!"Error creating object, use arguments %s"(getInfoArgs()));
            }

            T execute(FAI args) const
            {
                return componentFactoryDelegate().createComponent(args);
            }
        }
    }

    return new ComponentFactoryAdapterImpl!(T)(new WrapperArgsImpl);
}



@system unittest
{
    auto wFactory = createFactoryAdapterDelegate(() => new DepthItemFactory(), "a", 1.1);
    assert (wFactory);
    assert (wFactory.initialized);
    assert (wFactory.create().verify("*a*", 2.2, 0));
    assert (wFactory.create("s", 1.2).verify("*s*", 2.4, 0));
}


/**
 * Создает адаптер над фабрикой компонента используя экземпляр фабрики
 *
 * Params:
 * F  = Тип фабрики
 * T  = Тип возвращаемого фабрикой компонента
 * A  = Параметры метода создания компонента
 */
private ComponentFactoryAdapterImpl!(T) createFactoryAdapterInstance(F : ComponentFactory!(T), T, A...)(
            F componentFactory, A argsInit)
{
    return createFactoryAdapterDelegate!(F, T, A)(() => componentFactory, argsInit);
}



@system unittest
{
    auto wFactory = createFactoryAdapterInstance(new DepthItemFactory(), "a", 1.1);
    assert (wFactory);
    assert (wFactory.initialized);
    assert (wFactory.create().verify("*a*", 2.2, 0));
    assert (wFactory.create("s", 1.2).verify("*s*", 2.4, 0));

    auto eFactory = createFactoryAdapterInstance(new IItemEmptyFactory());
    assert (eFactory);
    assert (eFactory.initialized);
    assert (eFactory.create().verify("empty", 1.0, 0));
    assert (eFactory.create("s", 1.2).verify("empty", 1.0, 0));

    auto aFactory = createFactoryAdapterInstance(new ItemFactory());
    assert (!aFactory.initialized);
    assert (aFactory.create("b", 4.4).verify("b", 4.4, 0));

    assertThrown!DangoComponentException(aFactory.create());
}


/**
 * Создает адаптер над фабрикой компонента используя контейнер DI
 *
 * Params:
 * F  = Тип фабрики
 * T  = Тип возвращаемого фабрикой компонента
 * A  = Параметры метода создания компонента
 */
private ComponentFactoryAdapterImpl!T createFactoryAdapterAutowire(F : ComponentFactory!(T), T, A...)(
            shared(DependencyContainer) container, A argsInit)
{
    return createFactoryAdapterDelegate!(F, T, A)(() {
            auto cf = new ConstructorInjectingInstanceFactory!F(container);
            cf.factoryParameters = InstanceFactoryParameters(
                    typeid(F), CreatesSingleton.no);
            F factory = cast(F)cf.getInstance();
            container.autowire!F(factory);
            return factory;
        }, argsInit);
}



@system unittest
{
    auto cnt = createContainer();
    auto wFactory = createFactoryAdapterAutowire!CtorItemFactory(cnt, "a", 1.1);
    assert (wFactory);
    assert (wFactory.initialized);
    assert (wFactory.create().verify("*a*", 2.2, 0));
    assert (wFactory.create("s", 1.2).verify("*s*", 2.4, 0));

    auto eFactory = createFactoryAdapterAutowire!IItemEmptyFactory(cnt);
    assert (eFactory);
    assert (eFactory.initialized);
    assert (eFactory.create().verify("empty", 1.0, 0));
    assert (eFactory.create("s", 1.2).verify("empty", 1.0, 0));


    auto aFactory = createFactoryAdapterAutowire!ItemFactory(cnt);
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
    auto wFactory = createFactoryAdapterDelegate!(ItemFactory)(() {
            cnt.autowire!ItemFactory(factory);
            return factory;
        }, "a", 1.1);

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
Registration factoryExistingInstance(F : ComponentFactory!(I, A), I, A...)(
        Registration registration, F factory, A args)
{
    auto wFactory = createFactoryAdapterDelegate!F(() {
            registration.originatingContainer.autowire!F(factory);
            return factory;
        }, args);
    return registration.factoryAdapterInstance(wFactory);
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new ItemFactory();

    auto reg = cnt.registerNamed!(Item, "one")
        .factoryExistingInstance(factory, "b", 6.5);
    assert(reg);
    auto item = cnt.resolveNamed!Item("one");
    assert (item.verify("b", 6.5, 1));
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 * Params:
 * I = Интерфес компонента
 * F = Фабрика компонента
 */
Registration factoryInstance(F : ComponentFactory!(I, A), I, A...)(
        Registration registration, A args)
{
    auto wFactory = createFactoryAdapterAutowire!F(
            registration.originatingContainer, args);
    return registration.factoryAdapterInstance(wFactory);
}



@system unittest
{
    auto cnt = createContainer();
    auto reg = cnt.registerNamed!(Item, "one")
        .factoryInstance!ItemFactory("b", 6.5);
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
Registration registerComponentInstance(CT, F : ComponentFactory!(T), T, A...)(
        shared(DependencyContainer) container, F factory, A args) if (is (CT : T))
{
    auto wFactory = createFactoryAdapterDelegate!F(() {
            container.autowire!F(factory);
            return factory;
        }, args);
    auto wAuto = new ComponentFactoryAdapterAutowired!(T, CT)(wFactory);
    auto ret = container.register!(ComponentFactoryAdapter!T,
            ComponentFactoryAdapterAutowired!(T, CT)).existingInstance(wAuto);
    if (wFactory.initialized)
        container.register!(T, CT).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new IItemFactory();
    auto reg = cnt.registerComponentInstance!(Item)(factory, "c", 7.3);
    assert(reg);
    auto item = cnt.resolve!IItem();
    assert (item.verify("c", 7.3, 1));
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new DepthItemFactory();
    auto reg = cnt.registerComponentInstance!(Item)(factory, "c", 2.3);
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
    auto reg = cnt.registerComponentInstance!(Item)(factory);
    assert(reg);

    assertThrown!ResolveException(cnt.resolve!IItem);

    auto itemFact = cnt.resolve!(ComponentFactoryAdapter!IItem);
    assert(itemFact);

    auto item = itemFact.create("dd", 5.3);
    assert (item.verify("dd", 5.3, 0));

    assertThrown!DangoComponentException(itemFact.create());
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
        shared(DependencyContainer) container, A args) if (is (CT : T))
{
    auto wFactory = createFactoryAdapterAutowire!F(container, args);
    auto wAuto = new ComponentFactoryAdapterAutowired!(T, CT)(wFactory);
    auto ret = container.register!(ComponentFactoryAdapter!T,
            ComponentFactoryAdapterAutowired!(T, CT)).existingInstance(wAuto);
    if (wFactory.initialized)
        container.register!(T, CT).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto reg = cnt.registerComponent!(Item, IItemFactory)();
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
Registration registerNamedComponentInstance(CT, string Name, F : ComponentFactory!(T), T, A...)(
        shared(DependencyContainer) container, F factory, A args) if (is(CT : T))
{
    auto wFactory = createFactoryAdapterDelegate!F(() {
            container.autowire!F(factory);
            return factory;
        }, args);
    auto wAuto = new ComponentFactoryAdapterAutowired!(T, CT)(wFactory);
    auto ret = container.registerNamed!(ComponentFactoryAdapter!T,
            ComponentFactoryAdapterAutowired!(T, CT), Name).existingInstance(wAuto);
    if (wFactory.initialized)
        container.registerNamed!(T, CT, Name).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new IItemFactory();
    auto reg = cnt.registerNamedComponentInstance!(Item, "two")(factory, "d", 7.4);
    assert(reg);

    auto item = cnt.resolveNamed!IItem("two");
    assert (item.verify("d", 7.4, 1));

    auto itemFact = cnt.resolveNamed!(ComponentFactoryAdapter!IItem)("two");
    assert(itemFact);
    item = itemFact.create("dd", 5.3);
    assert (item.verify("dd", 5.3, 0));
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
        shared(DependencyContainer) container, A args) if (is(CT : T))
{
    auto wFactory = createFactoryAdapterAutowire!F(container, args);
    auto wAuto = new ComponentFactoryAdapterAutowired!(T, CT)(wFactory);
    auto ret = container.registerNamed!(ComponentFactoryAdapter!T,
            ComponentFactoryAdapterAutowired!(T, CT), Name).existingInstance(wAuto);
    if (wFactory.initialized)
        container.registerNamed!(T, CT, Name).factoryAdapterInstance(wFactory);
    return ret;
}



@system unittest
{
    auto cnt = createContainer();
    auto reg = cnt.registerNamedComponent!(Item, "two", IItemFactory)("d", 7.4);
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
    auto reg = cnt.registerComponentInstance!(Item)(factory, "c", 7.3);
    assert(reg);

    auto item = cnt.resolveComponent!IItem("r", 2.2);
    assert (item.verify("r", 2.2, 1));
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new ItemSingleFactory();
    auto reg = cnt.registerComponentInstance!(ItemSingle)(factory, "c", 7.3);
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
    auto reg = cnt.registerNamedComponentInstance!(Item, "four")(factory, "c", 7.3);
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
Registration registerComponentByCtor(SuperType, ConcreteType : SuperType, A...)(
        shared(DependencyContainer) container, A args)
{
    alias F = ComponentFactoryCtor!(SuperType, ConcreteType, A);
    return registerComponentInstance!(ConcreteType, F, SuperType, A)(container, new F(), args);
}



@system unittest
{
    auto cnt = createContainer();
    auto reg = cnt.registerComponentByCtor!(Item, Item)("e", 9.1);
    assert(reg);

    auto item = cnt.resolveComponent!Item();
    assert (item.verify("e", 9.1, 1));
    assertThrown!ResolveException(cnt.resolveComponent!IItem);

    reg = cnt.registerComponentByCtor!(IItem, Item)("ee", 9.2);
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
Registration registerNamedComponentByCtor(SuperType, ConcreteType : SuperType, string Name, A...)(
        shared(DependencyContainer) container, A args)
{
    alias F = ComponentFactoryCtor!(SuperType, ConcreteType, A);
    return registerNamedComponentInstance!(ConcreteType, Name, F, SuperType, A)(container,
            new F(), args);
}



@system unittest
{
    auto cnt = createContainer();

    auto reg = cnt.registerNamedComponentByCtor!(IItem, Item, "four")("f", 56.1);
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
Registration registerNamedComponentByCtor(SuperType, ConcreteType : SuperType, string Name, A...)(
        shared(DependencyContainer) container)
{
    alias F = ComponentFactoryCtor!(SuperType, ConcreteType, A);
    return registerNamedComponentInstance!(ConcreteType, Name, F, SuperType)(container,
            new F());
}



@system unittest
{
    auto cnt = createContainer();
    auto factory = new IItemFactory();

    auto reg = cnt.registerNamedComponentByCtor!(IItem, Item, "four", string, double)();
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
        .factoryExistingInstance(factory, "ITEM", 6.6);

    auto item = cnt.resolve!IItem;
    assert(item.verify("ITEM", 6.6, 1));

    item.value = 4.4;
    auto item2 = cnt.resolve!IItem;
    assert(item2.verify("ITEM", 4.4, 1));
}

