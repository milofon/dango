/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serialization;

public
{
    import uninode.core : UniNode;
    import uninode.serialization : optional,
           deserializeUniNode, serializeToUniNode;

    import dango.service.serialization.core : Serializer;
}

private
{
    import dango.system.container;

    import dango.service.serialization.json;
    import dango.service.serialization.msgpack;
}


/**
 * Контекст DI для сериализаторов
 */
class SerializerContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerFactory!(JsonSerializerFactory, JsonSerializer);
        container.registerFactory!(MsgPackSerializerFactory, MsgPackSerializer);
    }
}

