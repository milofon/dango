/**
 * Модуль содержит методы для работы со совйствами приложения
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-11
 */

module dango.system.properties;

public
{
    import optional.or : frontOr;
}

private
{
    import uniconf.core : UniConf, UniConfException;
}


/**
 * Извление конфигурации
 *
 * Params:
 * config = Объект содержащий необходимы ключ конфигурации
 * msg = Сообщение об ошибке
 *
 * Returns: name
 */
string getOrEnforce(T)(UniConf config, string key, string msg) @safe
{
    auto val = config.opt!T(key);
    if (val.empty)
        throw new UniConfException(msg);
    return val.front;
}


/**
 * Извление имени из объекта конфигурации
 *
 * Params:
 * config = Объект содержащий необходимы ключ конфигурации
 * msg = Сообщение об ошибке
 *
 * Returns: name
 */
string getNameOrEnforce(UniConf config, string msg) @safe
{
    if (config.canMapping)
        return config.getOrEnforce!string("__name", msg);
    else
    {
        auto val = config.opt!string;
        if (val.empty)
            throw new UniConfException(msg);
        return val.front;
    }
}

