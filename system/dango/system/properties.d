/**
 * Модуль содержит методы для работы со совйствами приложения
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-11
 */

module dango.system.properties;

private
{
    import std.typecons : Nullable;

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
T getOrEnforce(T)(UniConf config, string key, string msg) @safe
{
    auto val = config.opt!T(key);
    if (val.isNull)
        throw new UniConfException(msg);
    return val.get;
}

@("Should work getOrEnforce method with key")
@safe unittest
{
    import std.exception : assertThrown;
    auto conf = UniConf(["__name": UniConf("method")]);
    assert (conf.getOrEnforce!string("__name", "not found") == "method");
    conf = UniConf(1);
    assertThrown!UniConfException(conf.getOrEnforce!int("name", "not found"));
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
T getOrEnforce(T)(UniConf config, string msg) @safe
{
    auto val = config.opt!T();
    if (val.isNull)
        throw new UniConfException(msg);
    return val.get;
}

@("Should work getOrEnforce method")
@safe unittest
{
    import std.exception : assertThrown;
    auto conf = UniConf("method");
    assert (conf.getOrEnforce!string("not found") == "method");
    conf = UniConf(1);
    assertThrown!UniConfException(conf.getOrEnforce!string("not found"));
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
        if (val.isNull)
            throw new UniConfException(msg);
        return val.get;
    }
}

@("Should work getNameOrEnforce method")
@safe unittest
{
    import std.exception : assertThrown;
    UniConf conf = UniConf("method"); 
    assert (conf.getNameOrEnforce("not found") == "method");
    conf = UniConf(["__name": UniConf("method")]);
    assert (conf.getNameOrEnforce("not found") == "method");
    conf = UniConf(1);
    assertThrown!UniConfException(conf.getNameOrEnforce("not found"));
}


/**
 * Преобразует UniConf в массив
 * 
 * Params:
 * config = Объект конфигурации
 */
UniConf[] toSequence(UniConf config) @safe
{
    if (config.canSequence)
        return config.getSequence();
    else
        return [config];
}

@("Should work toSequence method")
@safe unittest
{
    UniConf conf = UniConf(1); 
    assert (conf.toSequence == [UniConf(1)]); 
    conf = UniConf([UniConf(1), UniConf(2)]);
    assert (conf.toSequence == [UniConf(1), UniConf(2)]); 
}


/**
 * Преобразует UniConf в массив
 * 
 * Params:
 * config = Объект конфигурации
 */
UniConf[] toSequence(UniConf config, string key) @safe
{
    auto val = config.opt!UniConf(key);
    if (val.isNull)
        return [];
    return val.get.toSequence();
}

@("Should work toSequence method with key")
@safe unittest
{
    UniConf conf = UniConf(["one": UniConf(1)]);
    assert (conf.toSequence("one") == [UniConf(1)]);
    conf = UniConf(["one": UniConf([UniConf(1), UniConf(2)])]);
    assert (conf.toSequence("one") == [UniConf(1), UniConf(2)]);
}


/**
 * Возвращает зачение из Nullable или альтернативное значение
 */
R getOrElse(R)(Nullable!R value, R alt) @safe nothrow
{
    if (value.isNull)
        return alt;
    return value.get;
}

@("Should work getOrElse method")
@safe unittest
{
    UniConf conf = UniConf(["one": UniConf(1)]);
    auto val = conf.opt!int("one");
    assert (!val.isNull);
    assert (val.getOrElse(2) == 1);
    assert (conf.opt!int("two").getOrElse(2) == 2);
}

