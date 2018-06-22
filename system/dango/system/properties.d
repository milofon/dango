/**
 * Модуль содержит методы для работы со совйствами приложения
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.properties;

private
{
    import proped;
    import poodinis : ApplicationContext;

    import dango.system.exception : configEnforce;
    import dango.system.container : ApplicationContainer;
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
    override void registerDependencies(ApplicationContainer container)
    {
        container.register!(PropertiesLoader, SDLPropertiesLoader);
        container.register!(PropertiesLoader, YAMLPropertiesLoader);
        container.register!(PropertiesLoader, JSONPropertiesLoader);
    }
}


/**
  * Создает функцию загрузчик
  * Params:
  *
  * container = Контейнер зависимостей
  */
Loader createLoaderFromContainer(ApplicationContainer container)
{
    PropertiesLoader[] loaders = container.resolveAll!PropertiesLoader;

    return (string fileName)
    {
        return loaders.loadProperties(fileName);
    };
}

