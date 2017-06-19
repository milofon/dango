/**
 * Модуль предоставляет объекты и методы для работы с именованным внедрением зависимостей (DI)
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.container.named;

private
{
   import poodinis; 
}

/**
 * Контейнер для управления именованных зависимостей
 * 
 * При помощи данного контейнера можно зарегистрировать именованную зависимось определенного типа.
 * Имена уникальны в рамках одного типа
 */
class NamedContainer
{
    private Registration[string][TypeInfo] registrations;

    /**
     * Регистрация зависимости
     *
     * Params:
     *
     * reg   = Объект регистрации типа
     * name  = Имя (метка) типа
     */
    void register(Registration reg, string name)
    {
        registrations[reg.registeredType][name] = reg;
    }

    /**
     * Получение объекта из именованного контейнера по имени
     *
     * Метод не учитывает опции, которые есть в оригинальном методе DependencyContainer
     *
     * Params:
     *
     * name = Имя требуемой зависимости
     *
     * See_Also: poodinis.container: DependencyContainer
     */
    RegistrationType resolve(RegistrationType)(string name)
    {
        TypeInfo resolveType = typeid(RegistrationType);

        auto candidates = resolveType in registrations;
        if (!candidates)
            throw new ResolveException("Type not registered.", resolveType);

        if (auto r = name in *candidates)
        {
            auto autowireContext = new AutowireInstantiationContext();
            autowireContext.autowireInstance = false;
            return cast(RegistrationType)(*r).getInstance(autowireContext);
        }

        return null;
    }
}


/**
 * Метод расширяет поведение DependencyContainer при помощи NamedContainer и добавляет возможность регистрировать именованные зависимости
 *
 * Params:
 *
 * container = Контейнер управляющий зависимостями
 * name      = Имя(метка) типа
 * options   = Опции для регистрации зависимости
 *
 * Returns: Объект регистрации
 */
Registration registerByName(SuperType, ConcreteType: SuperType)(shared(DependencyContainer) container, string name, RegistrationOption options = RegistrationOption.none)
{
    NamedContainer nc = container.resolve!NamedContainer(ResolveOption.registerBeforeResolving);
    Registration reg = container.register!(SuperType, ConcreteType)(options);
    nc.register(reg, name);
    return reg;
}


/**
 * Метод расширяет поведение DependencyContainer при помощи NamedContainer и добавляет возможность создать объект указав тип помеченный именем
 *
 * Params:
 *
 * container = Контейнер зависимостей
 * name      = Имя(метка) типа
 *
 * Returns: Объект зарегистрированного типа
 */
RegistrationType resolveByName(RegistrationType)(shared(DependencyContainer) container, string name)
{
    NamedContainer nc = container.resolve!NamedContainer(ResolveOption.registerBeforeResolving);
    return nc.resolve!RegistrationType(name);
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
QualifierType resolveByName(RegistrationType, QualifierType : RegistrationType)(shared(DependencyContainer) container, string name)
{
    return cast(QualifierType) resolveByName!RegistrationType(container, name);
}

