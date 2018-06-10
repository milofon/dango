/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serialization;

public
{
    import vibe.data.serialization : optional;

    import dango.service.serialization.core : Serializer, UniNode,
           marshalObject, unmarshalObject;
}

private
{
    import std.meta;

    import dango.service.factory;

    import dango.service.serialization.json : JsonSerializer;
    import dango.service.serialization.msgpack : MsgPackSerializer;
}


alias Serializers = AliasSeq!(
        "JSON", JsonSerializer,
        "MSGPACK", MsgPackSerializer
    );


alias SerializerFactory = ComponentFactory!(Serializers).Wrapper!Serializer;

