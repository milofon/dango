/**
 * Contains the implementation of the dependency container.
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-11
 */

module dango.inject.container;

private
{
    import std.algorithm.iteration : map, filter;
    import std.algorithm.searching : find, canFind;
    import std.format : fmt = format;
    import std.exception : assumeWontThrow;
    import std.uni : toUpper;
    import std.array : join, array;

    import dango.inject.injection : Inject, Named, inject;
    import dango.inject.factory : ComponentFactory;
    import dango.inject.provider;
    import dango.inject.exception;
}


/**
 * The dependency container maintains all dependencies registered with it.
 */
class DependencyContainer
{
    private @safe
    {
        Registration[][TypeInfo] _registrations;
        Registration[] autowireStack;
    }

    /**
     * Register a single value.
     *
     * A `ValueProvider` is used to provide the value.
     */
    Registration value(T)(T value) nothrow @safe
    {
        return this.provider(new ValueProvider!T(value));
    }

    /**
     * Register a single value with name.
     *
     * A `ValueProvider` is used to provide the value.
     */
    Registration value(T)(string name, T value) nothrow @safe
    {
        return this.provider(name, new ValueProvider!T(value));
    }

    /**
     * Register a Class.
     *
     * Instances are provided using a `ClassProvider` that injects dependencies using
     * this container.
     */
    Registration register(ConcreteType)() nothrow @safe
        if (is(ConcreteType == class))
    {
        return register!(ConcreteType, ConcreteType)();
    }

    /**
     * Register a Class.
     *
     * Instances are provided using a `ClassProvider` that injects dependencies using
     * this container.
     */
    Registration register(SuperType, ConcreteType : SuperType)() nothrow @safe
        if (is(ConcreteType == class))
    {
        Provider provider = new ClassProvider!(SuperType, ConcreteType)(this);
        TypeInfo registeredType = provider.registeredType;
        TypeInfo providedType = provider.providedType;

        if (auto existingCandidates = registeredType in _registrations)
        {
            auto existingRegistration = assumeWontThrow(find!((r) @trusted {
                        return r.providedType == providedType;
                    })(*existingCandidates));
            if (existingRegistration.length)
                return existingRegistration[0];
        }

        return this.provider(provider);
    }

    /**
     * Register a Class with name.
     *
     * Instances are provided using a `ClassProvider` that injects dependencies using
     * this container.
     */
    Registration register(ConcreteType)(string name) nothrow @safe
        if (is(ConcreteType == class))
    {
        return register!(ConcreteType, ConcreteType)(name);
    }

    /**
     * Register a Class with name.
     *
     * Instances are provided using a `ClassProvider` that injects dependencies using
     * this container.
     */
    Registration register(SuperType, ConcreteType : SuperType)(string name) nothrow @safe
        if (is(ConcreteType == class))
    {
        Provider provider = new ClassProvider!(SuperType, ConcreteType)(this);
        TypeInfo registeredType = provider.registeredType;
        TypeInfo providedType = provider.providedType;
        string uName = assumeWontThrow(name.toUpper);

        if (auto existingCandidates = registeredType in _registrations)
        {
            auto existingRegistration = assumeWontThrow(find!((r) @safe {
                        return r.isNamed && r.name == uName;
                    })(*existingCandidates));
            if (existingRegistration.length)
                return existingRegistration[0];
        }

        return this.provider(name, provider);
    }

    /**
     * Register a factory function for a type.
     */
    Registration factory(F : ComponentFactory!(T, A), T, A...)(A args) nothrow @safe
    {
        auto freg = this.register!(ComponentFactory!(T, A), F).singleInstance();
        auto fact = assumeWontThrow(resolveInjectdInstance!F(freg));
        return this.provider(new FactoryProvider!(F, T, A)(this, fact, args));
    }

    /**
     * Register a factory function for a type.
     */
    Registration factory(F : ComponentFactory!(T, A), T, A...)(string name, A args) nothrow @safe
    {
        auto freg = this.register!(ComponentFactory!(T, A), F)(name).singleInstance();
        auto fact = assumeWontThrow(resolveInjectdInstance!F(freg));
        return this.provider(name, new FactoryProvider!(F, T, A)(this, fact, args));
    }

    /**
     * Register a provider using the type returned by `provider.providedType`.
     */
    Registration provider(Provider provider) nothrow @safe
    {
        auto newRegistration = new Registration(provider);
        return addRegistration(provider.registeredType, newRegistration);
    }

    /**
     * Register a provider using the type returned by `provider.providedType`.
     */
    Registration provider(string name, Provider provider) nothrow @safe
    {
        auto newRegistration = new Registration(provider, assumeWontThrow(name.toUpper));
        return addRegistration(provider.registeredType, newRegistration);
    }

    /**
     * Resolve dependencies using a qualifier.
     *
     * Dependencies can only resolved using this method if they are registered by super type.
     *
     * Resolved dependencies are automatically autowired before being returned.
     */
    ResolveType resolve(ResolveType)() @safe
    {
        TypeInfo resolveType = typeid(ResolveType);

        auto candidates = resolveType in _registrations;
        if (!candidates)
            throw new ResolveDangoException("Type not registered.", resolveType);

        if (candidates.length > 1)
        {
            string candidateList = (*candidates).map!((c) => c.providedType.toString).join(',');
            throw new ResolveDangoException("Multiple qualified candidates available: " ~
                    candidateList ~ ". Please use a qualifier or name.", resolveType);
        }

        Registration registration = (*candidates)[0];
        return resolveInjectdInstance!ResolveType(registration);
    }

    /**
     * Resolve all dependencies registered to a super type.
     *
     * Returns:
     * An array of autowired instances is returned. The order is undetermined.
     */
    ResolveType[] resolveAll(ResolveType)() @safe
    {
        TypeInfo resolveType = typeid(ResolveType);

        auto candidates = resolveType in _registrations;
        if (!candidates)
            throw new ResolveDangoException("Type not registered.", resolveType);

        ResolveType[] result;
        foreach (registration; *candidates)
            result ~= resolveInjectdInstance!ResolveType(registration);

        return result;
    }

    /**
     * Resolve dependencies using a qualifier.
     *
     * Dependencies can only resolved using this method if they are registered by super type.
     *
     * Resolved dependencies are automatically autowired before being returned.
     */
    ResolveType resolve(ResolveType)(string name) @safe
    {
        TypeInfo resolveType = typeid(ResolveType);
        string uName = name.toUpper;

        auto candidates = resolveType in _registrations;
        if (!candidates)
            throw new ResolveDangoException("Type not registered.", resolveType);

        auto namedCandidates = filter!((r) {
                return r.isNamed && r.name == uName;
            })(*candidates).array;

        if (namedCandidates.length > 1)
        {
            string candidateList = namedCandidates.map!((c) => c.providedType.toString).join(',');
            throw new ResolveDangoException("Multiple qualified candidates available: " ~
                    candidateList ~ ".", resolveType);
        }
        else if (namedCandidates.length == 0)
            throw new ResolveDangoException(
                    fmt!"Type not registered with name '%s'."(uName), resolveType);

        Registration registration = namedCandidates[0];
        return resolveInjectdInstance!ResolveType(registration);
    }

    /**
     * Resolve all dependencies registered to a super type.
     *
     * Returns:
     * An array of autowired instances is returned. The order is undetermined.
     */
    ResolveType[] resolveAll(ResolveType)(string name) @safe
    {
        TypeInfo resolveType = typeid(ResolveType);
        string uName = name.toUpper;

        auto candidates = resolveType in _registrations;
        if (!candidates)
            throw new ResolveDangoException("Type not registered.", resolveType);

        auto namedCandidates = filter!((r) {
                return r.isNamed && r.name == uName;
            })(*candidates);

        ResolveType[] result;
        foreach (registration; namedCandidates)
            result ~= resolveInjectdInstance!ResolveType(registration);

        return result;
    }

    /**
     * Resolve dependencies using a qualifier.
     *
     * Dependencies can only resolved using this method if they are registered by super type.
     *
     * Resolved dependencies are automatically autowired before being returned.
     */
    QualifierType resolve(ResolveType, QualifierType : ResolveType)() @safe
    {
        TypeInfo resolveType = typeid(ResolveType);
        TypeInfo qualifierType = typeid(QualifierType);

        auto candidates = resolveType in _registrations;
        if (!candidates)
            throw new ResolveDangoException("Type not registered.", resolveType);

        auto typedCandidates = filter!((r) @trusted {
                return r.providedType == qualifierType;
            })(*candidates).array;

        if (typedCandidates.length > 1)
        {
            string candidateList = typedCandidates.map!((c) => c.providedType.toString).join(',');
            throw new ResolveDangoException("Multiple qualified candidates available: " ~
                    candidateList ~ ".", resolveType);
        }
        else if (typedCandidates.length == 0)
            throw new ResolveDangoException("Type not registered.", resolveType);

        Registration registration = typedCandidates[0];
        return resolveInjectdInstance!QualifierType(registration);
    }

    /**
     * Resolve all dependencies registered to a super type.
     *
     * Returns:
     * An array of autowired instances is returned. The order is undetermined.
     */
    QualifierType[] resolveAll(ResolveType, QualifierType : ResolveType)()
    {
        TypeInfo resolveType = typeid(ResolveType);
        TypeInfo qualifierType = typeid(QualifierType);

        auto candidates = resolveType in _registrations;
        if (!candidates)
            throw new ResolveDangoException("Type not registered.", resolveType);

        auto typedCandidates = filter!((r) @trusted {
                return r.providedType == qualifierType;
            })(*candidates);

        ResolveType[] result;
        foreach (registration; typedCandidates)
            result ~= resolveInjectdInstance!ResolveType(registration);

        return result;
    }


private:


    ResolveType resolveInjectdInstance(ResolveType)(Registration registration) @trusted
    {
        synchronized (this)
        {
            if (!(autowireStack.canFind(registration)))
            {
                autowireStack ~= registration;
                scope (exit)
                    autowireStack = autowireStack[0 .. $-1];
                return registration.provide!ResolveType(true);
            }
            else
                return registration.provide!ResolveType(false);
        }
    }


    Registration addRegistration(TypeInfo registeredType, Registration registration) nothrow @safe 
    {
        assumeWontThrow(() @safe {
            synchronized (this)
                _registrations[registeredType] ~= registration;
            }());
        return registration;
    }
}

@("Should work container with value")
@safe unittest
{
    auto cont = new DependencyContainer();
    auto reg = cont.value(1); 
    assert (!reg.isNamed);
    assert (cont.resolve!int == 1);

    reg = cont.value("two", 2);
    assert (reg.isNamed);
    assert (reg.name == "TWO");

    assert (cont._registrations[typeid(int)].length == 2);
    assert (cont.resolve!int("tWo") == 2);

    cont.value("hello");
    assert (cont.resolve!string() == "hello");    
    cont.value("name", "world");
    assertThrown!ResolveDangoException(cont.resolve!string);
    assert (cont.resolve!string("name") == "world");
}

version (unittest)
{
    import std.exception : assertThrown;
    interface Animal { string name() @safe; }
    class Cat : Animal {string name() { return "cat"; }}
    class Dog : Animal {string name() { return "dog"; }}
}

@("Should work container with concrete object")
@system unittest
{
    auto cont = new DependencyContainer();
    auto reg1 = cont.register!Cat();
    auto reg2 = cont.register!Cat();
    assert (reg1 == reg2);
    auto cat = cont.resolve!Cat;
    assert (cat && cat.name == "cat");
}

@("Should work container with qualified object")
@safe unittest
{
    auto cont = new DependencyContainer();
    auto reg1 = cont.register!(Animal, Cat)();
    assertThrown(cont.resolve!(Animal, Dog));

    auto cat = cont.resolve!Animal;
    assert (cat && cat.name == "cat");
    
    cat = cont.resolve!(Animal, Cat);
    assert (cat && cat.name == "cat");
}

@("Should work container with named object")
@safe unittest
{
    auto cont = new DependencyContainer();
    auto reg1 = cont.register!(Animal, Cat)("bar");
    assertThrown(cont.resolve!(Animal, Dog));

    auto cat = cont.resolve!Animal;
    assert (cat && cat.name == "cat");

    cat = cont.resolve!(Animal, Cat);
    assert (cat && cat.name == "cat");

    cat = cont.resolve!(Animal)("bar");
    assert (cat && cat.name == "cat");
}

@("Should work container with custom provider")
@safe unittest
{
    struct ItemDB { int value; }
    class CustomProvider : Provider
    {
        private int _initVal;
        this(int initVal) { _initVal = initVal; }
        TypeInfo providedType() const pure nothrow @safe { return typeid(ItemDB); }
        TypeInfo registeredType() const pure nothrow @safe { return typeid(ItemDB); }
        bool canSingleton() const pure nothrow @safe { return false; }
        Provider originalProvider() pure nothrow @safe { return this; }
        void withProvided(bool ii, void delegate(void*) @safe dg) @trusted
        {
            auto result = ItemDB(_initVal);
            dg(&result);
        }
    }

    auto cont = new DependencyContainer();
    cont.provider("one", new CustomProvider(1));
    cont.provider("two", new CustomProvider(2));
    assert (cont.resolve!ItemDB("one").value == 1);
    assert (cont.resolve!ItemDB("two").value == 2);
}

@("Should work container with factory")
@safe unittest
{
    interface Logger { int getLevel() @safe; }
    class ConsoleLogger : Logger
    {
        private int _level;
        this(int level) { _level = level; }
        int getLevel() @safe { return _level; }
    }
    class CustomFactory : ComponentFactory!(Logger, int)
    {
        Logger createComponent(int lvl) { return new ConsoleLogger(lvl); }
    }

    auto cont = new DependencyContainer();
    cont.factory!CustomFactory(10);

    auto ft = cont.resolve!(ComponentFactory!(Logger, int));
    assert (ft && ft.createComponent(11).getLevel == 11);

    auto v = cont.resolve!Logger;
    assert (v && v.getLevel == 10);
}

