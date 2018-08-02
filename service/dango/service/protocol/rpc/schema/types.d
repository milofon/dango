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
struct MethodSchema
{
    @Doc("Описание метода")
    string note;
    @Doc("Наименование метода")
    string name;
    @Doc("Информация о возвращаемом типе")
    MemberSchema retType;
    @Doc("Принимаемые параметры")
    MemberSchema[string] params;
}


/**
 * Описание модели
 */
struct ModelSchema
{
    @Doc("Наименование модели")
    string name;
    @Doc("Поля модели")
    MemberSchema[string] members;
}


/**
 * Описание перечисления
 */
struct EnumSchema
{
    @Doc("Наименование перечисления")
    string name;
    @Doc("Информация о базовом типе")
    TypeSchema type;
    @Doc("Значения")
    UniNode[string] values;
}


/**
 * Описание поля объекта
 */
struct MemberSchema
{
    @Doc("Описание поля")
    string note;
    @Doc("Тип поля")
    TypeSchema type;
    @Doc("Значение по умолчанию")
    @optional
    UniNode defVal; // значение по умолчанию
}


/**
 * Описание типа
 */
struct TypeSchema
{
    @Doc("Оригинальное представление поля")
    string original;
    @Doc("Принимаемый тип")
    string input;
    @Doc("Подробное описание составляющих типа")
    TypeSchemaDetail[] details;
}


/**
 * Подробное описание составляющей типа
 */
struct TypeSchemaDetail
{
    @Doc("Вид типа")
    string kind;
    @Doc("Наименование типа")
    string name;
}

