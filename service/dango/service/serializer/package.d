/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serializer;

public
{
    import dango.service.serializer.core : Serializer, UniNode,
           marshalObject, unmarshalObject;
}

private
{
    import poodinis : DependencyContainer, ApplicationContext;
    import dango.system.container : registerByName;

    import dango.service.serializer.json : JsonSerializer;
    import dango.service.serializer.msgpack : MsgPackSerializer;
}


class SerializerContext : ApplicationContext
{
    override void registerDependencies(shared(DependencyContainer) container)
    {
        container.registerByName!(Serializer, JsonSerializer)("json");
        container.registerByName!(Serializer, MsgPackSerializer)("msgpack");
    }
}
