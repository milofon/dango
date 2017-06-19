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
    import poodinis;

    import dango.system.container : registerByName;

    import proped;
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

