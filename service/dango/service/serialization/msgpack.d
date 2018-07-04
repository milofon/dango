/**
 * Модуль сериализатора MessagePack
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serialization.msgpack;

private
{
    import std.algorithm.searching : startsWith;

    import proped : Properties;
    import msgpack;

    import dango.system.component;
    import dango.service.types;
    import dango.service.serialization.core;
}



class MsgPackSerializer : BaseSerializer!"MSGPACK"
{
    private bool _withFieldName;


    this(bool withFieldName)
    {
        _withFieldName = withFieldName;
    }


    this()
    {
        this(false);
    }


    UniNode deserialize(Bytes bytes)
    {
        auto unpacker = StreamingUnpacker(bytes);
        unpacker.execute();
        return toUniNode(unpacker.purge);
    }


    Bytes serialize(UniNode node)
    {
        Value val = fromUniNode(node);
        auto packer = Packer(_withFieldName);
        val.toMsgpack(packer);
        return packer.stream.data.idup;
    }
}



class MsgPackSerializerFactory : SimpleComponentFactory!(Serializer, MsgPackSerializer)
{
    override MsgPackSerializer create(Properties config)
    {
        auto withFieldName = config.getOrElse!bool("withFieldName", false);
        MsgPackSerializer ret = new MsgPackSerializer(withFieldName);
        return ret;
    }
}


private:


UniNode toUniNode(Value input)
{
    UniNode convert(Value node)
    {
        switch(node.type) with (Value)
        {
            case Type.nil:
                return UniNode();
            case Type.boolean:
                return UniNode(node.via.boolean);
            case Type.unsigned:
                return UniNode(node.via.uinteger);
            case Type.signed:
                return UniNode(node.via.integer);
            case Type.floating:
                return UniNode(node.via.floating);
            case Type.raw:
                return UniNode(node.via.raw);
            case Type.array:
            {
                UniNode[] arr = new UniNode[](node.via.array.length);
                foreach(i, Value ch; node.via.array)
                    arr[i] = convert(ch);
                return UniNode(arr);
            }
            case Type.map:
            {
                UniNode[string] map;
                foreach(Value key, Value ch; node.via.map)
                {
                    if (key.type == Type.raw)
                    {
                        string k = cast(string)key.via.raw;
                        map[k] = convert(ch);
                    }
                }
                return UniNode(map);
            }
            default:
                return UniNode();
        }
    }

    return convert(input);
}



Value fromUniNode(UniNode input)
{
    Value convert(UniNode node)
    {
        switch(node.type) with (UniNode)
        {
            case Type.nil:
                return Value();
            case Type.boolean:
                return Value(node.get!bool);
            case Type.signed:
                return Value(node.get!long);
            case Type.unsigned:
                return Value(node.get!ulong);
            case Type.floating:
                return Value(node.get!double);
            case Type.raw:
                return Value(node.get!(ubyte[]));
            case Type.text:
                return Value(node.get!(string));
            case Type.array:
            {
                Value[] arr;
                foreach(UniNode ch; node.get!(UniNode[]))
                    arr ~= convert(ch);
                return Value(arr);
            }
            case Type.object:
            {
                Value[Value] map;
                foreach(string key, UniNode ch; node.get!(UniNode[string]))
                    map[Value(key)] = convert(ch);
                return Value(map);
            }
            default:
                return Value();
        }
    }

    return convert(input);
}

