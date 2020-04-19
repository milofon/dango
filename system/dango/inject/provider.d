/**
 * Contains the implementation of the provider.
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-11
 */

module dango.inject.provider;

private
{
    import std.format : fmt = format;
    import std.exception : enforce;
    import std.meta : anySatisfy, AliasSeq, Filter;
    import std.traits;

    import dango.inject.container: DependencyContainer, ComponentFactory;
    import dango.inject.exception : InjectDangoException;
    import dango.inject.injection : Inject, Named, inject;
}


/**
 * Dependency registration
 */
class Registration
{
    private 
    {
        Provider _provider;
        bool _isNamed;
        string _name;
    }

    /**
     * Main constructor
     */
    this(Provider provider) nothrow @safe
    {
        this._provider = provider;
        this._isNamed = false;
    }

    /**
     * Main constructor with name
     */
    this(Provider provider, string name) nothrow @safe
    {
        this._provider = provider;
        this._name = name;
        this._isNamed = true;
    }

    /**
     * Return a `TypeInfo` describing the type provided.
     */
    TypeInfo providedType() const pure nothrow @safe
    {
        return _provider.providedType();
    }

    /**
     * Return a `TypeInfo` describing the type registered.
     */
    TypeInfo registeredType() const pure nothrow @safe
    {
        return _provider.registeredType();
    }

    /**
     * Return a `string` describing the name.
     */
    string name() const pure nothrow @safe
    {
        return _name;
    }

    /**
     * Return isNamed registration.
     */
    bool isNamed() const pure nothrow @safe
    {
        return _isNamed;
    }


    T provide(T)(bool injectInstance) @safe
    {
        T result;
        _provider.withProvided(injectInstance, (val) @trusted {
                static if (is(T == interface) || is(T == class))
                {
                    Object o = *(cast(Object*)val);
                    result = cast(T)o;
                }
                else
                    result = *(cast(T*)val);
            });
        return result;
    }

    /**
     * Return maybe singleton registration;
     */
    bool canSingleton() const pure nothrow @safe
    {
        return _provider.canSingleton();
    }
}


/**
 * Interface for a provider for dependency injection.
 * A provider knows about the type it produces, and
 * can produce a value.
 */
interface Provider
{
    /**
     * Return a `TypeInfo` describing the type provided.
     */
    TypeInfo providedType() const pure nothrow @safe;

    /**
     * Return a `TypeInfo` describing the type registered.
     */
    TypeInfo registeredType() const pure nothrow @safe;

    /**
     * Produce the value.
     * A pointer to the value is passed to a delegate.
     *
     * Notes: The pointer may no longer be valid after `dg` returns, so the value
     * pointed to should be copied to persist it.
     */
    void withProvided(bool injectInstance, void delegate(void*) @safe dg) @safe;

    /**
     * Return maybe singleton provider
     */
    bool canSingleton() const pure nothrow @safe;

    /**
     * Return original provider
     */
    Provider originalProvider() pure nothrow @safe;
}


/**
 * A `Provider` that provides a value. The value is
 * provided at construction type and the same value
 * is returned each time provide is called.
 */
class ValueProvider(T) : Provider
{
    private T _value;

    /**
     * Common constructor
     */
    this(T value) nothrow @safe
    {
        this._value = value;
    }

    /**
     * Return a `TypeInfo` describing the type provided.
     */
    TypeInfo providedType() const pure nothrow @safe
    {
        return typeid(T);
    }

    /**
     * Return a `TypeInfo` describing the type registered.
     */
    TypeInfo registeredType() const pure nothrow @safe
    {
        return typeid(T);
    }

    /**
     * Produce the value.
     * A pointer to the value is passed to a delegate.
     *
     * Notes: The pointer may no longer be valid after `dg` returns, so the value
     * pointed to should be copied to persist it.
     */
    void withProvided(bool injectInstance, void delegate(void*) @safe dg) @safe
    {
        dg(&_value);
    }

    /**
     * Return maybe singleton provider
     */
    bool canSingleton() const pure nothrow @safe
    {
        return false;
    }

    /**
     * Return original provider
     */
    Provider originalProvider() pure nothrow @safe
    {
        return this;
    }
}

@("Should work value provider")
@system unittest
{
    auto provider = new ValueProvider!int(10);
    assert (provider.providedType == typeid(int));
    assert (provider._value == 10);
}

@("Should work value provider existing class")
@system unittest
{
    class C {}
    auto c = new C();
    auto provider = new ValueProvider!C(c);
    assert (provider.providedType == typeid(C));
    assert (provider._value is c);
}


/**
 * A provider that uses a factory to get the value.
 */
class FactoryProvider(F : ComponentFactory!(T, A), T, A...) : Provider
{   
    private 
    {
        DependencyContainer _container;
        F _factory;
        A _args;
    }

    /**
     * Main constructor
     */
    this(DependencyContainer container, F factory, A args)
    {
        this._container = container;
        this._factory = factory;
        this._args = args;
    }

    /**
     * Return a `TypeInfo` describing the type provided.
     */
    TypeInfo providedType() const nothrow @safe
    {
        return typeid(T);
    }

    /**
     * Return a `TypeInfo` describing the type registered.
     */
    TypeInfo registeredType() const pure nothrow @safe
    {
        return typeid(T);
    }

    /**
     * Produce the value.
     * A pointer to the value is passed to a delegate.
     *
     * Notes: The pointer may no longer be valid after `dg` returns, so the value
     * pointed to should be copied to persist it.
     */
    void withProvided(bool injectInstance, void delegate(void*) @safe dg) @trusted
    {
        static if (is(T == class) || is (T == interface))
        {
            T instance = _factory.createComponent(_args);
            Object result = cast(Object)instance;
        }
        else
            T result = _factory.createComponent(_args);

        dg(&result);
    }

    /**
     * Return maybe singleton provider
     */
    bool canSingleton() const pure nothrow @safe
    {
        return false;
    }

    /**
     * Return original provider
     */
    Provider originalProvider() pure nothrow @safe
    {
        return this;
    }
}

@("Should work factory provider")
@system unittest
{
    interface Animal { string name() @safe; }
    class Cat : Animal { 
        private string _name;
        this(string name) @safe { _name = name; }
        string name() @safe { return _name; }
    }
    class TestFactory : ComponentFactory!(Animal, string)
    {
        Animal createComponent(string name) @safe
        {
            return new Cat(name);
        }
    }

    auto container = new DependencyContainer();
    auto factory = new TestFactory();
    Provider provider = new FactoryProvider!(TestFactory)(container, factory, "cat");
    assert (provider.providedType == typeid(Animal));   
    auto reg = new Registration(provider);
    auto result = reg.provide!Animal(false);
    assert (result.name == "cat");
}


/**
 * A Provider that instantiates instances of a class.
 *
 * Arguments to the constructor are resolved using a `Resolver` (typically a `Container`).
 * If an `Injectable` annotation is on the class, then the template arguments to the `Injectable`
 * determine how the injected arguments should be resolved. Otherwise, the argument types for the
 * first constructor are used.
 */
class ClassProvider(I, T : I) : Provider
    if (is(T == class))
{
    private 
    {
        DependencyContainer _container;
        bool isBeingInjected;
    }

    /**
     * Main constructor
     */
    this(DependencyContainer container) @safe nothrow
    {
        this._container = container;
    }

    /**
     * Return a `TypeInfo` describing the type provided.
     */
    TypeInfo providedType() const pure nothrow @safe
    {
        return typeid(T);
    }

    /**
     * Return a `TypeInfo` describing the type registered.
     */
    TypeInfo registeredType() const pure nothrow @safe
    {
        return typeid(I);
    }

    /**
     * Produce the value.
     * A pointer to the value is passed to a delegate.
     *
     * Notes: The pointer may no longer be valid after `dg` returns, so the value
     * pointed to should be copied to persist it.
     */
    void withProvided(bool injectInstance, void delegate(void*) @safe dg) @trusted
    {
        enforce!InjectDangoException(_container,
                "A dependency container is not defined. Cannot perform constructor" ~ 
                    " injection without one.");
        enforce!InjectDangoException(!isBeingInjected,
                fmt!("%s is already being created and injected; possible circular" ~ 
                    "dependencies in constructors?")(T.stringof));

        V resolveMember(V, P...)()
        {
            enum IsNamed(alias N) = is(typeof(N) == Named);
            enum named = Filter!(IsNamed, P);
            static if (named.length)
            {
                enum name = named[0].name;
                static if (isDynamicArray!V && !isSomeString!V)
                    return _container.resolveAll!(ForeachType!V)(name);
                else
                    return _container.resolve!V(name);
            }
            else
            {
                static if (isDynamicArray!V && !isSomeString!V)
                    return _container.resolveAll!(ForeachType!V);
                else
                    return _container.resolve!V;
            }
        }

        template IsCtorInjected(alias ctor)
        {
            template IsInjectAttribute(alias A)
            {
                enum IsInjectAttribute = (is(A == Inject!Q, Q) ||
                    __traits(isSame, A, Inject));
            }
            enum IsCtorInjected = anySatisfy!(IsInjectAttribute,
                    __traits(getAttributes, ctor));
        }

        T instance = null;
        static if (__traits(compiles, __traits(getOverloads, T, `__ctor`)))
        {
            foreach(ctor ; __traits(getOverloads, T, `__ctor`))
            {
                static if (IsCtorInjected!ctor)
                {
                    enum CtorLen = __traits(getAttributes, ctor).length;
                    alias Params = Parameters!ctor;
                    isBeingInjected = true;
                    scope(exit) 
                        isBeingInjected = false;
                    Params params = void;
                    foreach (i, param; Params)
                    {
                        alias SP = Params[i..i+1];
                        static if (__traits(compiles, __traits(getAttributes, SP)))
                        {
                            alias Attr = AliasSeq!(__traits(getAttributes, SP));
                            static if (Attr.length)
                                params[i] = resolveMember!(param, Attr[CtorLen..Attr.length]);
                            else
                                params[i] = resolveMember!(param, Attr);
                        }
                        else
                            params[i] = resolveMember!(param);
                    }
                    instance = new T(params);
                    break;
                }
            }
        }

        if (instance is null)
            instance = cast(T)(typeid(T).create());

        enforce!InjectDangoException(instance !is null,
                "Unable to create instance of type" ~ T.stringof ~
                    ", does it have injectable constructors?");

        if (injectInstance)
            _container.inject!T(instance);

        dg(&instance);
    }

    /**
     * Return maybe singleton provider
     */
    bool canSingleton() const pure nothrow @safe
    {
        return true;
    }

    /**
     * Return original provider
     */
    Provider originalProvider() pure nothrow @safe
    {
        return this;
    }
}


version (unittest)
{
    import std.exception : assertThrown; 
    interface Printer { string name() @safe; }
    class LaserPrinter : Printer { 
        string name() @safe { return "LaserJet 2000"; }
    }
    struct Page {}
    interface Report { 
        string print() @safe; 
        Page[] pages() @safe;
        string title() @safe;
    }
    abstract class BaseReport : Report
    {
        Page[] pages() @safe { return []; }
        string title() @safe { return "t"; }
    }
    class SimpleReport : BaseReport { 
        string print() @safe { return "simple"; }
    }
    class ErrorReport : BaseReport {
        @Inject
        this(Report parent) @safe {}
        string print() @safe { return "error"; }
    }
    class AdditionalReport : BaseReport {
        private {
            Printer _printer;
            string _title;
            Page[] _pages;
        }
        @Inject
        this(Printer printer, Page[] pages, @Named("title") string title)
        {
            this._printer = printer;
            this._title = title;
            this._pages = pages;
        }
        string print() @safe { return _printer.name; }
        override Page[] pages() @safe { return _pages; }
        override string title() @safe { return _title; }
    }
}

@("Should work register concrete named class")
@system unittest
{
    auto cont = new DependencyContainer();
    auto reg1 = cont.register!SimpleReport("r1");
    auto reg2 = cont.register!SimpleReport("r2");
    assert (reg1 != reg2);
    assertThrown(cont.resolve!Report);
    auto reps = cont.resolveAll!SimpleReport;
    assert (reps.length == 2);
    auto report = cont.resolve!SimpleReport("r1");
    assert (report && report.print == "simple");
}

@("Should work resolve class by circular constructor")
@system unittest
{
    auto cont = new DependencyContainer();
    cont.register!(Report, ErrorReport);
    assertThrown(cont.resolve!Report);
}

@("Should work resolve class by constructor")
@system unittest
{
    auto cont = new DependencyContainer();
    cont.register!(Printer, LaserPrinter);
    cont.value("p1", Page());
    cont.value("p2", Page());
    cont.value("title", "printer");
    cont.register!(Report, AdditionalReport);
    auto rep = cont.resolve!(Report);
    assert (rep);
    assert (rep.print == "LaserJet 2000");
    assert (rep.pages.length == 2);
    assert (rep.title == "printer");
}


/**
 * A Provider that uses another provider to create an instance
 * the first time `provide` is called. Future calls to `provide`
 * will return this same instance.
 */
class SingletonProvider : Provider
{
    private
    {
        Provider _original;
        void* _instance;
    }

    /**
     * Common constructor
     */
    this(Provider orig) pure nothrow @safe
    {
        this._original = orig;
    }

    /**
     * Return a `TypeInfo` describing the type provided.
     */
    TypeInfo providedType() const pure nothrow @safe
    {
        return _original.providedType();
    }

    /**
     * Return a `TypeInfo` describing the type registered.
     */
    TypeInfo registeredType() const pure nothrow @safe
    {
        return _original.registeredType();
    }

    /**
     * Produce the value.
     * A pointer to the value is passed to a delegate.
     *
     * Notes: The pointer may no longer be valid after `dg` returns, so the value
     * pointed to should be copied to persist it.
     */
    void withProvided(bool injectInstance, void delegate(void*) @safe dg) @safe
    {
        if (_instance is null)
        {
            synchronized (this)
            {
                if (_instance is null)
                    createInstance(injectInstance);
            }
        }
        dg(_instance);
    }

    /**
     * Return maybe singleton provider
     */
    bool canSingleton() const pure nothrow @safe
    {
        return false;
    }

    /**
     * Return original provider
     */
    Provider originalProvider() pure nothrow @safe
    {
        return _original;
    }

    /**
     * Create an instance using the base provider.
     *
     * Since we don't know if the value is allocated on the stack
     * or the heap, we need to allocate space on the heap and copy it
     * there.
     */
    private void createInstance(bool injectInstance) @trusted
    {
        import core.memory : GC;
        import core.stdc.string : memcpy;
        auto info = _original.providedType();
        _original.withProvided(injectInstance, (void* ptr) @trusted {
                if (ptr !is null)
                {
                    _instance = GC.malloc(info.tsize, GC.getAttr(ptr), info);
                    memcpy(_instance, ptr, info.tsize);
                }
            });
        info.postblit(_instance);
    }
}

@("Should work SingletonProvider")
@system unittest
{
    class BaseProvider : Provider
    {
        private int counter = 0;

        TypeInfo providedType() const pure nothrow @safe
        {
            return typeid(int);
        }

        TypeInfo registeredType() const pure nothrow @safe
        {
            return typeid(int);
        }

        void withProvided(bool ii, void delegate(void*) @safe dg) @safe
        {
            counter++;
            dg(&counter);
        }

        bool canSingleton() const pure nothrow @safe
        {
            return false;
        }

        Provider originalProvider() pure nothrow @safe
        {
            return this;
        }
    }

    auto provider = new SingletonProvider(new BaseProvider());
    assert (provider.providedType == typeid(int));
    int first;
    provider.withProvided(false, (void* val) @trusted {
            first = *(cast(int*)val);
        });
    assert (first == 1);
    provider.withProvided(false, (void* val) @trusted {
            first = *(cast(int*)val);
        });
    assert (first == 1);
}


/**
 * Scopes registrations to return the same instance every time a given registration is resolved.
 *
 * Effectively makes the given registration a singleton.
 */
Registration singleInstance(Registration registration) nothrow @safe
{
    if (registration.canSingleton)
        registration._provider = new SingletonProvider(registration._provider);
    return registration;
}


/**
 * Scopes registrations to return a new instance every time the given registration is resolved.
 */
Registration newInstance(Registration registration) nothrow @safe
{
    registration._provider = registration._provider.originalProvider();
    return registration;
}

@("Should work singleInstance and newInstance")
@safe unittest
{
    class Counter { private int counter; }
    auto cont = new DependencyContainer();
    auto reg = cont.register!(Counter).singleInstance;
    auto cnt = cont.resolve!Counter;
    cnt.counter++;
    cnt = cont.resolve!Counter;
    assert (cnt.counter == 1);
    reg.newInstance; 
    cnt = cont.resolve!Counter;
    assert (cnt.counter == 0);
}


/**
 * Scopes registrations to return the given instance every time the given registration is resolved.
 */
Registration existingInstance(T)(Registration registration, T instance) @trusted
    if (is(T == class))
{
    if (!canBuiltinInheritance!T(registration.providedType))
        throw new InjectDangoException(fmt!"Type '%s' not provide '%s'"(
                    registration.providedType, typeid(T)));

    if (!registration.canSingleton)
        throw new InjectDangoException(fmt!"Type '%s' not support singleton"(
                    registration.providedType));

    registration.singleInstance();

    auto singleProvider = cast(SingletonProvider)registration._provider;
    if (singleProvider)
    {
        Object obj = cast(Object)instance;
        singleProvider._instance = cast(void*)&obj;
    }
    return registration;
}

@("Should work existingInstance")
@safe unittest
{
    class Counter { 
        private int _counter;
        this(int c) { _counter = c; }
    }
    auto cont = new DependencyContainer();
    auto counter = new Counter(3);
    cont.register!(Counter).existingInstance(counter);
    auto rcnt = cont.resolve!Counter;
    assert (rcnt._counter == 3);
}


/**
 * Check TypeInfo
 */
private bool canBuiltinInheritance(T)(TypeInfo info) nothrow @trusted
    if (is(T == class))
{
    import std.traits : BaseClassesTuple, InterfacesTuple;
    import std.meta : AliasSeq, staticMap, Filter, staticIndexOf;

    template ToTypeInfo(A)
    {
        enum ToTypeInfo = typeid(A);
    }

    template IsTypeInfo(A)
    {
        enum IsTypeInfo = !is(A == Object);
    }

    enum Infos = staticMap!(ToTypeInfo, T, Filter!(IsTypeInfo,
            AliasSeq!(BaseClassesTuple!T, InterfacesTuple!T)));

    try
        foreach (typeInfo; Infos)
        {
            if (typeInfo == info)
                return true;
        }
    catch (Exception e)
        return false;

    return false;
}

@("Should work canBuiltinInheritance")
@safe unittest
{
    interface TestT {}
    interface TestA {}
    interface TestB : TestA {}
    abstract class TestC : TestB {}
    class TestD : TestC {}
    class TestE : TestD {}
    assert (!canBuiltinInheritance!TestE(typeid(int)));
    assert (canBuiltinInheritance!TestE(typeid(TestA)));
}

