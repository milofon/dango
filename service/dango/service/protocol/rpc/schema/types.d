/**
 * Модуль типов пакета документации RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-31
 */

module dango.service.protocol.rpc.schema.types;

public
{
    import dango.service.serialization : UniNode;
}

private
{
    import std.typecons : Nullable;
    import vibe.data.serialization : optional;
}


/**
 * Аннотация определяет документацию для обработчика команды
 */
struct Doc
{
    string content;
}


/**
 * Документация метода
 */
struct MethodDoc
{
    @Doc("Наименование метода")
    string method;
    @Doc("Описание метода")
    string note;
    @Doc("Информация о возвращаемом типе")
    FieldDoc retDoc;
    @Doc("Принимаемые параметры")
    FieldDoc[string] params;
}


/**
 * Документация типа
 */
struct ModelDoc
{
    @Doc("Наименование модели")
    string name;
    @Doc("Поля модели")
    FieldDoc[string] members;
}


/**
 * Документация поля
 */
struct FieldDoc
{
    @Doc("Описание поля")
    string note; // примечание
    @Doc("Тип поля")
    string typeDoc; // наименование типа
    @Doc("Значение по умолчанию")
    @optional
    UniNode defVal; // значение по умолчанию
    @Doc("Ссылка на модель")
    @optional
    Nullable!string typeLink; // ссылка на составной тип
}


alias RegisterMethodDoc = void delegate(MethodDoc);


alias RegisterModelDoc = void delegate(ModelDoc[]);

