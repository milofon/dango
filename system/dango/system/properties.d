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
    import uniconf.core.exception : configEnforce;
}

private
{
    import uniconf.core;
    import poodinis : ApplicationContext;

    import dango.system.container : ApplicationContainer;
}


/**
 * Извление имени из объекта конфигурации
 * Params:
 * config = Объект содержащий необходимы ключ конфигурации
 * msg = Сообщение об ошибке
 */
string getNameOrEnforce(Config config, string msg)
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

