/**
 * Основной модуль сериализатора
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serialization.core;

public
{
    import uninode.core : UniNode;
    import dango.service.types : Bytes;
}

private
{
    import uninode.serialization;

    import dango.system.inject;
}


/**
 * Основной интерфейс сериализатор
 */
interface Serializer : NamedComponent
{
    /**
     * Сериализация объекта языка в массив байт
     * Params:
     * object = Объект для преобразования
     * Return: массив байт
     */
    final Bytes serializeObject(T)(T object)
    {
        return serialize(serializeToUniNode!T(object));
    }

    /**
     * Десериализация массива байт в объект языка
     * Params:
     * bytes = Массив байт
     * Return: T
     */
    final T deserializeObject(T)(Bytes bytes)
    {
        return deserializeUniNode!T(deserialize(bytes));
    }

    /**
     * Десериализация массива байт в UniNode
     * Params:
     * bytes = Массив байт
     * Return: UniNode
     */
    UniNode deserialize(Bytes bytes);

    /**
     * Сериализация UniNode в массив байт
     * Params:
     * node = Данные в UniNode
     * Return: массив байт
     */
    Bytes serialize(UniNode node);
}

