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
    import std.uni : toUpper;

    import poodinis;
}


/**
 * Тип обертка над именованными
 */
interface Named(T)
{
    string name() @property;

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
        private ConcreteType _registrationType;


        string name() @property
        {
            return NAME;
        }


        ConcreteType value() @property
        {
            return this._registrationType;
        }
    }
}


/**
 * Метод добавляет возможность регистрировать именованные зависимости
 *
 * Params:
 *
 * container = Контейнер управляющий зависимостями
 * name      = Имя(метка) типа
 * options   = Опции для регистрации зависимости
 *
 * Returns: Объект регистрации
 */
Registration registerNamed(SuperType, ConcreteType : SuperType, string Name)(
            shared(DependencyContainer) container,
            RegistrationOption options = RegistrationOption.none)
{
    auto ret = container.register!(SuperType, ConcreteType)(options);
    alias W = NamedWrapper!(ConcreteType, Name).Wrapper!SuperType;
    container.register!(Named!SuperType, W)(options);
    return ret;
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

    auto objects = container.resolveAll!(Named!RegistrationType);
    auto findResult = objects.find!((o) => o.name == uName);
    if (!findResult.length)
        throw new ResolveException(fmt!"Type not registered or name '%s' found."(uName),
                resolveType);

    return findResult[0].value;
}

