/**
 * Модуль работы с компонентами и фабриками к ним
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-22
 */

module dango.inject.factory;

private
{
    import std.meta : Filter;
    import std.format : fmt = format;
    import std.traits : hasMember;

    import bolts : isFunctionOver;

    import dango.inject.container : DependencyContainer;
    import dango.inject.provider : ClassProvider;
    import dango.inject.injection : inject;
}


/**
 * Интерфейс фабрики для создания компонентов системы
 * Params:
 * I - Конструируемый тип
 * A - Типы аргументов
 */
interface ComponentFactory(C, A...)
    if (is(C == class) || is(C == interface))
{
    alias ComponentType = C;

    /**
     * Создает компонент
     */
    C createComponent(A args) @safe;
}


/**
 * Метод позволяет создавать компоненты на основе анализа конструкторов
 * Params:
 * C = Тип создаваемого объекта
 * args = Принимаемые аргументы
 */
C createComponentByCtor(C, A...)(A args)
    if (is(C == class) || is(C == interface))
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


version (unittest)
{
    interface Server
    {
        string host() @safe;
        ushort port() @safe;
    }

    class HTTPServer : Server
    {
        private 
        {
            string _host;
            ushort _port;
        }

        this() @safe {}

        this(string host, ushort port) @safe
        {
            this._host = host;
            this._port = port;
        }

        string host() @safe { return _host; }
        ushort port() @safe { return _port; }
    }

    class ServerFactory : ComponentFactory!(Server, string, ushort)
    {
        Server createComponent(string host, ushort port)
        {
            return new HTTPServer(host, port);
        }
    }
}

@("Should work createComponentByCtor method")
@safe unittest
{

    auto server = createComponentByCtor!(HTTPServer, string, ushort)("host", 3);
    assert (server.host == "host");
    assert (server.port == 3);

    server = createComponentByCtor!(HTTPServer)();
    assert (server.host == "");
    assert (server.port == 0);
}


/**
 * Фабрика автосгенерирована на основе конструктора компонента
 */
template ComponentFactoryCtor(C, CT : C, A...)
    if (is(C == class) || is(C == interface))
{
    class ComponentFactoryCtor : ComponentFactory!(C, DependencyContainer, A)
    {
        alias ConcreteType = CT;

        /**
         * See_Also: ComponentFactory.createComponent
         */
        C createComponent(DependencyContainer container, A args) @safe
        {
            auto result = createComponentByCtor!(CT, A)(args);
            inject!CT(container, result);
            return result;
        }
    }
}

@("Should work ComponentFactoryCtor")
@safe unittest
{
    auto cont = new DependencyContainer();
    auto factory = new ComponentFactoryCtor!(Server, HTTPServer, string, ushort)();
    auto server = factory.createComponent(cont, "host", 3);
    assert (server.host == "host");
    assert (server.port == 3);
}


/**
 * Оборачивание существующей фабрики в фабрику создающую 
 * объект с инъекцией зависимости
 */
template WrapDependencyFactory(F : ComponentFactory!(C, A), C, A...)
{
    static if (A.length && is(A[0] == DependencyContainer))
        alias AA = A[1..$];
    else
        alias AA = A;

    class WrapDependencyFactory : ComponentFactory!(C, DependencyContainer, AA)
    {
        /**
         * See_Also: ComponentFactory.createComponent
         */
        C createComponent(DependencyContainer container, AA args) @safe
        {
            auto provider = new ClassProvider!(F, F)(container);
            F factory;
            provider.withProvided(true, (val) @trusted {
                    factory = cast(F)(*(cast(Object*)val));
                });
            static if (A.length && is(A[0] == DependencyContainer))
                return factory.createComponent(container, args);
            else
                return factory.createComponent(args);
        }
    }
}

@("Should work wrapDependencyFactory")
@safe unittest
{
    alias F = ComponentFactoryCtor!(Server, HTTPServer, string, ushort);
    auto cont = new DependencyContainer();
    auto factory = new WrapDependencyFactory!(F)();
    auto server = factory.createComponent(cont, "host", 3);
    assert (server.host == "host");
    assert (server.port == 3);

    auto factory2 = new WrapDependencyFactory!ServerFactory();
    server = factory.createComponent(cont, "host", 3);
    assert (server.host == "host");
    assert (server.port == 3);
}

