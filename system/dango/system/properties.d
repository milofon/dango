/**
 * Модуль содержит методы для работы со совйствами приложения
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.properties;

public
{
    import poodinis : Registration;
}

private
{
    import poodinis;
    import proped;

    import dango.system.container : registerByName;
    import dango.system.exception : configEnforce;
}


/**
 * Получение настроек или генерация исключения
 * Params:
 * config = Объект содержащий необходимы ключ конфигурации
 * key = Ключ конфигруации
 * msg = Сообщение об ошибке
 */
T getOrEnforce(T)(Properties config, string key, lazy string msg)
{
    static if (is(T == Properties))
        auto ret = config.sub(key);
    else
        auto ret = config.get!T(key);

    configEnforce(!ret.isNull, msg);
    return ret.get;
}


/**
 * Извление имени из объекта конфигурации
 * Params:
 * config = Объект содержащий необходимы ключ конфигурации
 * msg = Сообщение об ошибке
 */
string getNameOrEnforce(Properties config, string msg)
{
    if (config.isObject)
        return config.getOrEnforce!string("name", msg);
    else
    {
        auto val = config.get!string;
        configEnforce(!val.isNull, msg);
        return val.get;
    }
}

/**
 * Контекст для регистрации системных компоненетов
 */
class PropertiesContext : ApplicationContext
{
    public override void registerDependencies(shared(DependencyContainer) container)
	{
        container.registerByName!(PropertiesLoader, SDLPropertiesLoader)("SDL");
        container.registerByName!(PropertiesLoader, YAMLPropertiesLoader)("YAML");
        container.registerByName!(PropertiesLoader, JSONPropertiesLoader)("JSON");
	}
}


/**
 * Класс обертка на объектом настроек для распространения в DI контейнере
 */
class PropertiesProxy
{
    Properties _properties;
    alias _properties this;

    this(Properties properties)
    {
        _properties = properties;
    }
}


/**
  * Создает функцию загрузчик
  * Params:
  *
  * container = Контейнер зависимостей
  */
Loader createLoaderFromContainer(shared(DependencyContainer) container)
{
    PropertiesLoader[] loaders = container.resolveAll!PropertiesLoader;

    return (string fileName)
    {
        return loaders.loadProperties(fileName);
    };
}


/**
 * Функция позволяет назначить фабрику передающую параметры в конструктор
 * для зарегистрированной в контейнере класса
 * Params:
 *
 * registration = Объект регистрации в контейнере
 * config       = Конфигурация
 */
Registration propertiesInstance(T)(Registration registration, Properties config) {

    Object propertiesInstanceMethod()
    {
        return new T(config);
    }

    registration.instanceFactory = new InstanceFactory(registration.instanceType,
            CreatesSingleton.yes, null, &propertiesInstanceMethod);
    return registration;
}


/**
 * Шаблон для регистрации зависимостей массово
 * Используется для более простой регистрации зависимостей в контейнер DI
 *
 * Params:
 *
 * pairs = Массив из пар (наименование, класс)
 *
 * Example:
 * --------------------
 * auto callback = (Registration reg, string name, Properties cfg) {};
 * registerControllerDependencies!("api", ControllerApi)(container, config, callback);
 * --------------------
 */
mixin template registerPropertiesDependencies(C, pairs...)
{
    template GenerateSwitch()
    {
        template GenerateSwitchBody(tpairs...)
        {
            static if (tpairs.length > 0)
            {
                enum GenerateSwitchBody = `
                    case ("` ~ tpairs[0]  ~ `"):
                        auto reg = container.register!(C, ` ~ tpairs[1].stringof ~ `)
                            .propertiesInstance!(` ~ tpairs[1].stringof ~ `)(cfg);
                        if (callback !is null)
                            callback(reg, name, cfg);
                        break;` ~ GenerateSwitchBody!(tpairs[2..$]);
            }
            else
                enum GenerateSwitchBody = "";
        }
        enum GenerateSwitch = "switch(name)\n{" ~ GenerateSwitchBody!(pairs) ~ "\ndefault: break;\n}";
    }

    void registerPropertiesDependencies(shared(DependencyContainer) container, Properties config,
            void function(Registration, string, Properties) callback = null)
    {
        pragma(msg, __MODULE__);
        // pragma(msg, GenerateSwitch!());
        foreach (Properties cfg; config.getArray())
        {
            auto pName = cfg.get!string("name");
            if (pName.isNull)
                continue;
            string name = pName.get;
            mixin(GenerateSwitch!());
        }
    }
}


/**
 * Функция для регистрации существующего контекста
 * Params:
 *
 * container = Контейнер зависимостей
 * ctx       = Объект контекста
 */
void registerExistsContext(Context : ApplicationContext)(shared(DependencyContainer) container, Context ctx)
{
    ctx.registerDependencies(container);
    ctx.registerContextComponents(container);
    container.register!(ApplicationContext, Context)().existingInstance(ctx);
    autowire(container, ctx);
}


void registerExtContext(Context : ApplicationContext)(shared(DependencyContainer) container, Properties config)
{
    auto context = new Context();
    context.registerDependencies(container, config);
    context.registerContextComponents(container);
    container.register!(ApplicationContext, Context)().existingInstance(context);
    autowire(container, context);
}

