/**
 * Модуль предоставляет объекты и методы для работы с именованным внедрением зависимостей (DI)
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-05-31
 */

module dango.system.container.named;

private
{
    import std.algorithm.searching : find;
    import std.format : fmt = format;
    import std.traits : isFunction, hasUDA;
    import std.uni : toUpper;

    import poodinis;

    import dango.system.container.exception : DangoContainerException;
}


/**
 * Метод добавляет возможность регистрировать именованные зависимости
 *
 * Params:
 *
 * container = Контейнер управляющий зависимостями
 * Name      = Имя(метка) типа
 * options   = Опции для регистрации зависимости
 *
 * Returns: Объект регистрации
 */
Registration registerNamed(SuperType, ConcreteType : SuperType, string Name)(
            shared(DependencyContainer) container,
            RegistrationOption options = RegistrationOption.none)
{
    TypeInfo registeredType = typeid(SuperType);

    auto instanceFactory = new ConstructorInjectingInstanceFactory!ConcreteType(container);
    auto newRegistration = new AutowiredRegistration!ConcreteType(registeredType,
            instanceFactory, container);
    newRegistration.singleInstance();

    alias W = NamedWrapper!(ConcreteType, Name.toUpper).Wrapper!SuperType;
    auto wrapper = new W(newRegistration);

    container.register!(Named!SuperType, W)(options)
        .existingInstance(wrapper);

    return newRegistration;
}


/**
 * Метод добавляет возможность регистрировать именованные зависимости
 *
 * Params:
 *
 * container = Контейнер управляющий зависимостями
 * Name      = Имя(метка) типа
 * options   = Опции для регистрации зависимости
 *
 * Returns: Объект регистрации
 */
Registration registerNamed(ConcreteType, string Name)(
            shared(DependencyContainer) container,
            RegistrationOption options = RegistrationOption.none)
{
    return registerNamed!(ConcreteType, ConcreteType, Name)(container, options);
}


/**
 * Метод добавляет возможность создать объект указав тип помеченный именем
 *
 * Params:
 *
 * container = Контейнер зависимостей
 * name      = Имя(метка) типа
 *
 * Returns: Объект требуемого типа
 */
RegistrationType resolveNamed(RegistrationType)(
            shared(DependencyContainer) container, string name,
            ResolveOption resolveOptions = ResolveOption.none)
{
    return resolveNamed!(RegistrationType, RegistrationType)(
            container, name, resolveOptions);
}


/**
 * Метод расширяет поведение DependencyContainer при помощи NamedContainer и добавляет возможность создать объект указав тип помеченный именем
 *
 * Params:
 *
 * container = Контейнер зависимостей
 * name      = Имя(метка) типа
 *
 * Returns: Объект требуемого типа
 */
QualifierType resolveNamed(RegistrationType, QualifierType : RegistrationType)(
            shared(DependencyContainer) container, string name,
            ResolveOption resolveOptions = ResolveOption.none)
{
    TypeInfo resolveType = typeid(RegistrationType);
    auto uName = name.toUpper;

    auto objects = container.resolveAll!(Named!RegistrationType)(resolveOptions);
    auto findResult = objects.find!((o) => o.name == uName);
    if (!findResult.length)
    {
        if (resolveOptions | ResolveOption.noResolveException)
            return null;
        else
            throw new ResolveException(fmt!"Type not registered or name '%s' found."(uName),
                    resolveType);
    }

    return findResult[0].value();
}


private:


/**
 * Тип обертка над именованными
 */
interface Named(T)
{
    string name() @property const;

    T value() @property;
}


/**
 * Контейнер для управления именованных зависимостей
 *
 * При помощи данного контейнера можно зарегистрировать именованную зависимось
 * определенного типа.
 *
 * Имена уникальны в рамках одного типа
 */
template NamedWrapper(ConcreteType, string NAME)
{
    class Wrapper(SuperType) : Named!SuperType
    {
        @Autowire
        private Registration _registration;


        this(Registration registration)
        {
            this._registration = registration;
        }


        string name() @property const
        {
            return NAME;
        }


        ConcreteType value() @property
        {
            try
            {
                ConcreteType newInstance = cast(ConcreteType)_registration
                    .getInstance(new AutowireInstantiationContext());
                callPostConstructors(newInstance);
                return newInstance;
            }
            catch (ValueInjectionException e)
            {
                throw new ResolveException(e, typeid(ConcreteType));
            }
        }


        private void callPostConstructors(Type)(Type instance)
        {
            foreach (memberName; __traits(allMembers, Type))
            {
                static if (__traits(compiles, __traits(getProtection, __traits(getMember, instance, memberName)))
                        && __traits(getProtection, __traits(getMember, instance, memberName)) == "public"
                        && isFunction!(__traits(getMember, instance, memberName))
                        && hasUDA!(__traits(getMember, instance, memberName), PostConstruct))
                {
                    __traits(getMember, instance, memberName)();
                }
            }
        }
    }
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


    interface Animal
    {
        string say();
    }


    class Cat : Animal
    {
        @Value("cat")
        string name;

        string say()
        {
            return name ~ ", meow";
        }
    }


    class Leon : Animal
    {
        string name;

        this(string name)
        {
            this.name = name;
        }

        string say()
        {
            return name ~ ", meow";
        }

        @PostConstruct
        void postConst()
        {
            this.name = "super " ~ name;
        }
    }


    class Dog : Animal
    {
        @Value("dog")
        string name;

        string say()
        {
            return name ~ ", wow";
        }
    }
}



@system unittest
{

    auto cnt = new shared(DependencyContainer);
    cnt.register!(ValueInjector!string, StringValueInjector)
        .existingInstance(new StringValueInjector("super "));

    cnt.registerNamed!(Animal, Cat, "barsik")();
    cnt.registerNamed!(Animal, Dog, "tuzik")();
    cnt.registerNamed!(Animal, Leon, "murzik")()
        .existingInstance(new Leon("leon"));

    assert(cnt.resolveNamed!Animal("murzik").say == "super leon, meow");
    assert(cnt.resolveNamed!Animal("Tuzik").say == "super dog, wow");
    assert(cnt.resolveNamed!Animal("barsik").say == "super cat, meow");
}



version (unittest)
{
    private void registerAnimals(shared(DependencyContainer) cnt)
    {
        class Cow : Animal
        {
            string say()
            {
                return "myy";
            }
        }

        cnt.registerNamed!(Animal, Cow, "burenka")();
    }
}



@system unittest
{
    auto cnt = new shared(DependencyContainer);
    cnt.register!(ValueInjector!string, StringValueInjector)
        .existingInstance(new StringValueInjector("super "));
    registerAnimals(cnt);

    assert(cnt.resolveNamed!Animal("burenka").say == "myy");
}

