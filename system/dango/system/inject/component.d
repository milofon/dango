/**
 * Модуль работы с компонентами и фабриками к ним
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-26
 */

module dango.system.inject.component;

private
{
    import std.traits : isCallable, Parameters, ReturnType, hasMember,
            TemplateArgsOf, TransitiveBaseTypeTuple, TemplateOf;
    import std.format : fmt = format;
    import std.meta : staticMap, Filter, staticIndexOf;

    import bolts : isFunctionOver;
    import poodinis;

    import dango.system.inject.exception;
    import dango.system.inject.named : registerNamed, resolveNamed;
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
    import uniconf.core : Config;

    enum CONFIG_TIMEOUT = 300;

    class ConfigValueInjector : ValueInjector!Config
    {
        private Config root;

        this (Config config)
        {
            this.root = config;
        }

        Config get(string key)
        {
            return root.getOrEnforce!Config(key, "Not defined configuration " ~ key);
        }
    }

    interface Component
    {
        bool isFactoryAutowired() @property; // Фабрика с инъекцией зависимостей
    }

    enum StoreType
    {
        NONE,
        FILE,
        MEMORY
    }

    interface Store : Component
    {
        StoreType type() @property;
    }

    class MemoryStore : Store
    {
        private bool isFactory;

        this()
        {
            isFactory = false;
        }

        this(bool isFactory = false)
        {
            isFactory = isFactory;
        }

        StoreType type() @property
        {
            return StoreType.MEMORY;
        }

        bool isFactoryAutowired() @property
        {
            return isFactory;
        }
    }

    class FileStore : Store
    {
        private bool isFactory;

        this()
        {
            isFactory = false;
        }

        this(bool isFactory = false)
        {
            isFactory = isFactory;
        }

        StoreType type() @property
        {
            return StoreType.FILE;
        }

        bool isFactoryAutowired() @property
        {
            return isFactory;
        }
    }

    class StoreFactory : ComponentFactory!(Store, StoreType)
    {
        Store createComponent(StoreType type)
        {
            final switch (type) with (StoreType)
            {
                case NONE:
                    return null;
                case FILE:
                    return new FileStore(true);
                case MEMORY:
                    return new MemoryStore(true);
            }
        }
    }

    interface Server : Component
    {
        bool isCreateOverFactory() @property; // Компонент создан через конструктор с параметрами
        bool isAutowiredValue() @property; // Статус процесса инъекции зависимостей
        string host() @property;
        ushort port() @property;
        StoreType storeType() @property;
    }

    class HTTPServer : Server
    {
        @Value("timeout")
        Config timeout;

        @Autowire
        Store store;

        private
        {
            bool _isCreateOverFactory;
            bool _isFactoryAutowired;
            string _host;
            ushort _port;
        }

        this()
        {
            _isCreateOverFactory = false;
        }

        this(bool ifa)
        {
            _isCreateOverFactory = true;
            _isFactoryAutowired = ifa;
        }

        this(string host, ushort port, bool ifa)
        {
            _isCreateOverFactory = true;
            _isFactoryAutowired = ifa;
            _host = host;
            _port = port;
        }

        bool isFactoryAutowired() @property
        {
            return _isFactoryAutowired;
        }

        bool isCreateOverFactory() @property
        {
            return _isCreateOverFactory;
        }

        bool isAutowiredValue() @property
        {
            return (store !is null) && !timeout.get!int.isNull;
        }

        string host() @property
        {
            return _host;
        }

        ushort port() @property
        {
            return _port;
        }

        StoreType storeType() @property
        {
            return store.type();
        }
    }

    class EmptyServerFactory : ComponentFactory!(Server)
    {
        @Autowire
        Store store;

        Server createComponent()
        {
            return new HTTPServer((store !is null));
        }
    }

    class ServerFactory : ComponentFactory!(Server, string, ushort)
    {
        @Autowire
        Store store;

        uint _count;

        int count() @property
        {
            return _count;
        }

        Server createComponent(string host, ushort port)
        {
            _count++;
            return new HTTPServer(host, port, store !is null);
        }
    }

    class ResetServerFactory : ServerFactory
    {
        @Autowire
        Store store;

        override Server createComponent(string host, ushort port)
        {
            return new HTTPServer("127.0.0.1", 53, store !is null);
        }
    }

    shared(DependencyContainer) createContainer()
    {
        auto config = Config(["timeout": Config(CONFIG_TIMEOUT)]);
        auto cnt = new shared(DependencyContainer)();
        cnt.register!(ValueInjector!Config, ConfigValueInjector)
            .existingInstance(new ConfigValueInjector(config));
        return cnt;
    }
}



@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Server, HTTPServer);
    cnt.register!(Store, MemoryStore);

    auto server = cnt.resolve!Server;
    assert (!server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert(server.storeType == StoreType.MEMORY);

    void checkFactoryType(T, F)()
    {
        auto factory = new F();
        assert (is(factory.ComponentType == T));
    }

    checkFactoryType!(Server, EmptyServerFactory);
    checkFactoryType!(Server, ServerFactory);
    checkFactoryType!(Server, ResetServerFactory);
    checkFactoryType!(Store, StoreFactory);
}


/**
 * Делегат возвращающий новый экземпляр компонента
 */
private alias ComponentResolver(C, A...) = C delegate(A args);


/**
 * Класс-обертка фабрики с возможностью прединициализации аргументов
 *
 * Params:
 * C = Класс компонента
 * A = Принимаемые аргументы
 */
private final class ComponentFactoryInitWrapper(C, A...)
{
    private
    {
        ComponentResolver!(C, A) _componentResolver;
        A _initArgs;
        bool _initialized;
    }


    this(ComponentResolver!(C, A) componentResolver)
    {
        _componentResolver = componentResolver;
        _initialized = (A.length == 0);
    }

    /**
     * Возвращает состояние прединициализации фабрики
     */
    bool initialized() @property
    {
        return _initialized;
    }

    /**
     * Прединициализация фабрики
     *
     * Params:
     * args = Аргументы
     */
    void preInitialize(A args)
    {
        _initArgs = args;
        _initialized = true;
    }

    /**
     * Функция принимает произвольный набор аргументов и возвращает
     * новый экземпляр компонента. Если передан пустой набор аргументов и
     * фабрика инициализирована, то фабрика возвращает компонент созданный
     * на основе прединициализированных аргументов
     *
     *
     * Params:
     * args = Аргументы
     */
    C createInstance(AR...)(AR args)
    {
        static if (AR.length > 0)
        {
            static assert (AR.length == A.length,
                    fmt!("Trying to factory %s but have %s.")(A.stringof, AR.stringof));
            foreach (i, TT; AR)
                static assert (is(TT == A[i]),
                        fmt!("Trying to factory %s but have %s.")(A.stringof, AR.stringof));
            return _componentResolver(args);
        }
        else
        {
            if (_initialized)
                return _componentResolver(_initArgs);
            else
                throw new DangoComponentException("Factory not initialized");
        }
    }
}



@system unittest
{
    auto factory = new ServerFactory();
    auto wrp = new ComponentFactoryInitWrapper!(Server, string, ushort)(&factory.createComponent);
    assert (!wrp.initialized);

    auto server = wrp.createInstance!(string, ushort)("127.0.0.1", 44);
    assert (server.host == "127.0.0.1");
    assert (server.port == 44);
    assert (factory.count == 1);

    assertThrown!DangoComponentException(wrp.createInstance());
    wrp.preInitialize("192.168.0.1", 80);
    assert (factory.count == 1);

    server = wrp.createInstance();
    assert (server.host == "192.168.0.1");
    assert (server.port == 80);
    assert (factory.count == 2);
}



@system unittest
{
    auto factory = new EmptyServerFactory();
    auto wrp = new ComponentFactoryInitWrapper!Server(&factory.createComponent);
    auto server = wrp.createInstance();
    assert (server.host == "");
    assert (server.port == 0);
}


/**
 * Класс-обертка фабрики с позволяющая скрывать набор аргументов
 *
 * Params:
 * C = Класс компонента
 */
final class ComponentFactoryWrapper(C)
{
    private
    {
        interface Wrapper
        {
            C createInstance();

            bool initialized() @property;
        }

        interface WrapperArgs(A...) : Wrapper
        {
            C createInstance(A args);

            void preInitialize(A args);
        }

        Wrapper _wrapper;
        TypeInfo[] _typeInfos;
    }


    this(CR)(CR componentResolver) if (isCallable!CR && is(ReturnType!CR : C))
    {
        alias A = Parameters!CR;
        auto initWrapper = new ComponentFactoryInitWrapper!(C, A)(componentResolver);

        template ByTypeId(D)
        {
            enum ByTypeId = typeid(D);
        }

        _wrapper = new class WrapperArgs!A
        {
            C createInstance()
            {
                return initWrapper.createInstance();
            }

            static if (A.length > 0)
            C createInstance(A args)
            {
                return initWrapper.createInstance(args);
            }

            void preInitialize(A args)
            {
                initWrapper.preInitialize(args);
            }

            bool initialized() @property
            {
                return initWrapper.initialized();
            }
        };

        _typeInfos = [staticMap!(ByTypeId, A)];
    }

    /**
     * Функция принимает произвольный набор аргументов и инициализирует фабрику
     *
     * Params:
     * args = Аргументы
     */
    void preInitialize(AR...)(AR args)
    {
        if (_wrapper is null)
            throw new DangoComponentException("Factory not initialized");

        if (args.length != _typeInfos.length)
            throw new Exception(
                    fmt!"Error initialize factory, use arguments %s"(_typeInfos));

        auto wrapperArgs = cast(WrapperArgs!AR)_wrapper;
        if (wrapperArgs is null)
            throw new Exception(fmt!"Error initialize factory, use arguments %s"(_typeInfos));

        wrapperArgs.preInitialize(args);
    }

    /**
     * Функция принимает произвольный набор аргументов и возвращает
     * новый экземпляр компонента. Если передан пустой набор аргументов и
     * фабрика инициализирована, то фабрика возвращает компонент созданный
     * на основе прединициализированных аргументов
     *
     *
     * Params:
     * args = Аргументы
     */
    C createInstance(AR...)(AR args)
    {
        if (_wrapper is null)
            throw new DangoComponentException("Factory not initialized");

        if (args.length == _typeInfos.length)
        {
            auto wrapperArgs = cast(WrapperArgs!AR)_wrapper;
            if (wrapperArgs is null)
                throw new Exception(
                        fmt!"Error creating object, use arguments %s"(_typeInfos));
            return wrapperArgs.createInstance(args);
        }
        else
            return _wrapper.createInstance();
    }

    /**
     * Возвращает состояние прединициализации фабрики
     */
    bool initialized() @property
    {
        return _wrapper.initialized();
    }
}



@system unittest
{
    auto factory = new ServerFactory();
    auto wrp = new ComponentFactoryWrapper!(Server)(&factory.createComponent);
    assert (!wrp.initialized);

    auto server = wrp.createInstance!(string, ushort)("127.0.0.1", 44);
    assert (server.host == "127.0.0.1");
    assert (server.port == 44);
    assert (factory.count == 1);

    assertThrown!DangoComponentException(wrp.createInstance());
    wrp.preInitialize!(string, ushort)("192.168.0.1", 80);

    server = wrp.createInstance();
    assert (server.host == "192.168.0.1");
    assert (server.port == 80);
    assert (factory.count == 2);
}



@system unittest
{
    auto factory = new EmptyServerFactory();
    auto wrp = new ComponentFactoryWrapper!Server(&factory.createComponent);
    auto server = wrp.createInstance();
    assert (server.host == "");
    assert (server.port == 0);
}


/**
 * Метод позволяет создавать компоненты на основе анализа конструкторов
 * Params:
 * C = Тип создаваемого объекта
 * args = Принимаемые аргументы
 */
C createComponentByCtor(C, A...)(A args)
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
    auto server = createComponentByCtor!(HTTPServer, string, ushort, bool)("host", 3, false);
    assert (server.host == "host");
    assert (server.port == 3);

    server = createComponentByCtor!(HTTPServer)();
    assert (server.host == "");
    assert (server.port == 0);
}


/**
 * Фабрика автосгенерирована на основе конструктора компонента
 * Params:
 * I = Компонент
 * A = Аргументы
 */
class ComponentFactoryCtor(C, CT : C, A...) : ComponentFactory!(C, A)
{
    /**
     * See_Also: ComponentFactory.createComponent
     */
    C createComponent(A args)
    {
        return createComponentByCtor!(CT, A)(args);
    }
}



@system unittest
{
    auto factory = new ComponentFactoryCtor!(Server, HTTPServer, string, ushort, bool)();
    auto server = factory.createComponent("host", 3, false);
    assert (server.host == "host");
    assert (server.port == 3);
}


private template ComponentFactoryArgs(F : ComponentFactory!(C, A), C, A...)
{
    alias ComponentFactoryArgs = A;
}


/**
 * Создает обертку над фабрикой.
 *
 * Params:
 * F = Фабрика компонента
 * C = Тип компонента
 * A = Аргументы
 */
private ComponentFactoryWrapper!C createFactoryWrapper(F : ComponentFactory!(C), C, CR, A...)(
        shared(DependencyContainer) container, CR componentResolver, A args)
{
    alias AR = ComponentFactoryArgs!F;
    static assert (is (CR == ComponentResolver!(C, AR)));

    auto argsWrapper = new ComponentFactoryWrapper!C(componentResolver);

    static if (A.length > 0)
        argsWrapper.preInitialize(args);

    return argsWrapper;
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 *
 * Params:
 * F = Фабрика компонента
 * C = Тип компонента
 * A = Аргументы
 */
private Registration factoryExistingInstance(F : ComponentFactory!(C, A), C, A...)(
            Registration registration, F factory, A args)
{
    auto createSingleton = registration.instanceFactory.factoryParameters.createsSingleton;

    C resolver(A a)
    {
        registration.originatingContainer.autowire!F(factory);
        return factory.createComponent(a);
    }

    auto argsWrapper = createFactoryWrapper!(F, C, ComponentResolver!(C, A), A)(
            registration.originatingContainer,
            &resolver, args);

    InstanceFactoryMethod method = ()
    {
        return cast(Object)argsWrapper.createInstance();
    };

    registration.instanceFactory.factoryParameters = InstanceFactoryParameters(
        registration.instanceType, createSingleton, null, method);
    return registration;
}



@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, FileStore);

    auto factory = new ServerFactory();
    auto reg = cnt.register!(Server, HTTPServer)
        .factoryExistingInstance!ServerFactory(factory, "192.168.0.1", 9090);
    assert(reg);

    auto server = cnt.resolve!Server;
    assert (server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert (server.storeType == StoreType.FILE);
    assert (server.isFactoryAutowired);
    assert (factory.count == 1);

    server = cnt.resolve!Server;
    assert (factory.count == 1);
}



@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, FileStore);

    auto factory = new ServerFactory();
    auto reg = cnt.register!(Server, HTTPServer)
        .newInstance
        .factoryExistingInstance!ServerFactory(factory, "192.168.0.1", 9090);
    assert(reg);

    auto server = cnt.resolve!Server;
    assert (server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert (server.storeType == StoreType.FILE);
    assert (server.isFactoryAutowired);
    assert (factory.count == 1);

    server = cnt.resolve!Server;
    assert (factory.count == 2);
}


/**
 * Модификация регистрации компонента в DI
 * Добавление возможности создавать компоненты при помощи фабрики
 *
 * Params:
 * F = Фабрика компонента
 * C = Тип компонента
 * A = Аргументы
 */
Registration factoryInstance(F : ComponentFactory!(C, A), C, A...)(
            Registration registration, A args)
{
    return factoryExistingInstance!(F, C, A)(registration, new F(), args);
}



@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, FileStore);

    auto reg = cnt.register!(Server, HTTPServer)
            .factoryInstance!ServerFactory("10.81.3.11", 3301);
    assert (reg);

    auto server = cnt.resolve!Server;
    assert (server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert (server.storeType == StoreType.FILE);
    assert (server.isFactoryAutowired);
}


/**
 * Регистрация фабрики компонента в контейнер DI
 *
 * Params:
 * container = Контейнер DI
 * factory   = Экземпляр фабрики
 * args      = Аргументы
 */
Registration registerExistingFactory(CT, F : ComponentFactory!(C), C, A...)(
        shared(DependencyContainer) container, F factory, A args) if (is(CT : C))
{
    alias AR = ComponentFactoryArgs!F;
    C resolver(AR a)
    {
        container.autowire!F(factory);
        CT ret = cast(CT)factory.createComponent(a);
        container.autowire!CT(ret);
        return ret;
    }

    InstanceFactoryMethod method = ()
    {
        return createFactoryWrapper!(F, C, ComponentResolver!(C, AR),  A)(
                    container, &resolver, args);
    };

    auto reg = container.register!(ComponentFactoryWrapper!C).newInstance;
    reg.instanceFactory.factoryParameters = InstanceFactoryParameters(
            reg.instanceType, CreatesSingleton.no, null, method);

    return reg;
}


/**
 * Регистрация фабрики компонента в контейнер DI
 *
 * Params:
 * container = Контейнер DI
 * args      = Аргументы
 */
Registration registerFactory(CT, F : ComponentFactory!(C), C, A...)(
        shared(DependencyContainer) container, A args) if (is(CT : C))
{
    return registerExistingFactory!(CT, F, C, A)(container, new F(), args);
}


/**
 * Возвращает фабрику компонента
 *
 * Params:
 * container = Контейнер DI
 * resolveOpt = Опции резолвинга
 */
ComponentFactoryWrapper!C resolveFactory(C)(shared(DependencyContainer) container,
        ResolveOption resolveOpt = ResolveOption.none)
{
    return container.resolve!(ComponentFactoryWrapper!(C))(resolveOpt);
}


@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, FileStore);

    auto factory = new ServerFactory();

    auto reg = cnt.registerExistingFactory!HTTPServer(factory);
    assert (reg);
    auto wrp = cnt.resolveFactory!Server();
    assert (!wrp.initialized);

    auto server = wrp.createInstance("192.168.0.1", cast(ushort)5050);
    assert (server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert (server.isFactoryAutowired);
    assert (server.host == "192.168.0.1");
    assert (server.port == 5050);
    assert (factory.count == 1);
}


@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, FileStore);

    auto factory = new ServerFactory();

    auto reg = cnt.registerExistingFactory!HTTPServer(factory, "10.88.3.6", cast(ushort)4040);
    assert (reg);
    auto wrp = cnt.resolveFactory!Server();
    assert (wrp.initialized);

    auto server = wrp.createInstance();
    assert (server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert (server.isFactoryAutowired);
    assert (server.host == "10.88.3.6");
    assert (server.port == 4040);
    assert (factory.count == 1);
}


@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, MemoryStore);

    auto reg = cnt.register!(Server, HTTPServer)
        .factoryInstance!ServerFactory("1", 2);
    assert(reg);
}


/**
 * Возвращает все зарегистрированные фабрики для компонента
 *
 * Params:
 * container  = Контейнер DI
 * resolveOpt = Опции резолвинга
 */
ComponentFactoryWrapper!C[] resolveAllFactory(C)(shared(DependencyContainer) container,
        ResolveOption resolveOpt = ResolveOption.none)
{
    return container.resolveAll!(ComponentFactoryWrapper!C)(resolveOpt);
}


/**
 * Регистрация именованной фабрики компонента в контейнер DI
 *
 * Params:
 * container = Контейнер DI
 * factory   = Экземпляр фабрики
 * args      = Аргументы
 */
Registration registerNamedExistingFactory(CT, string N, F : ComponentFactory!(C), C, A...)(
        shared(DependencyContainer) container, F factory, A args)
{
    alias AR = ComponentFactoryArgs!F;
    C resolver(AR a)
    {
        container.autowire!F(factory);
        CT ret = cast(CT)factory.createComponent(a);
        container.autowire!CT(ret);
        return ret;
    }

    InstanceFactoryMethod method = ()
    {
        return createFactoryWrapper!(F, C, ComponentResolver!(C, AR),  A)(
                    container, &resolver, args);
    };

    auto reg = container.registerNamed!(ComponentFactoryWrapper!C, N).newInstance;
    reg.instanceFactory.factoryParameters = InstanceFactoryParameters(
            reg.instanceType, CreatesSingleton.no, null, method);

    return reg;
}


/**
 * Регистрация именованной фабрики компонента в контейнер DI
 *
 * Params:
 * container = Контейнер DI
 * args      = Аргументы
 */
Registration registerNamedFactory(CT, string N, F : ComponentFactory!(C), C, A...)(
        shared(DependencyContainer) container, A args)
{
    return registerNamedExistingFactory!(CT, N, F, C, A)(container, new F(), args);
}


/**
 * Возвращает именованную фабрику компонента
 *
 * Params:
 * container = Контейнер DI
 * name      = Имя фабрики
 * resolveOpt = Опции резолвинга
 */
ComponentFactoryWrapper!C resolveNamedFactory(C)(shared(DependencyContainer) container, string name, ResolveOption resolveOpt = ResolveOption.none)
{
    return container.resolveNamed!(ComponentFactoryWrapper!C)(name, resolveOpt);
}



@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, FileStore);

    auto factory = new ServerFactory();

    auto reg = cnt.registerNamedExistingFactory!(HTTPServer, "S")(
            factory, "10.88.3.6", cast(ushort)4040);
    assert (reg);
    auto wrp = cnt.resolveNamedFactory!Server("s");
    assert (wrp.initialized);

    auto server = wrp.createInstance();
    assert (server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert (server.isFactoryAutowired);
    assert (server.host == "10.88.3.6");
    assert (server.port == 4040);
    assert (factory.count == 1);
}



@system unittest
{
    auto cnt = createContainer();
    cnt.register!(Store, MemoryStore);
    auto factory = new ServerFactory();

    auto reg = cnt.registerNamedExistingFactory!(HTTPServer, "front")(factory);
    assert(reg);

    auto wrp = cnt.resolveNamedFactory!(Server)("FRONT");
    assert (!wrp.initialized);

    auto server = wrp.createInstance("163.99.88.77", cast(ushort)44);
    assert (server.isCreateOverFactory);
    assert (server.isAutowiredValue);
    assert (server.isFactoryAutowired);
    assert (server.host == "163.99.88.77");
    assert (server.port == 44);
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

