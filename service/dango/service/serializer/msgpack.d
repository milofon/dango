/**
 * Модуль сериализатора MessagePack
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serializer.msgpack;

private
{
    import dango.service.serializer.core;
}


class MsgPackSerializer : Serializer
{
    override UniNode deserialize(ubyte[] bytes)
    {
        return UniNode();
    }


    override ubyte[] serialize(UniNode node)
    {
        return [];
    }
}
