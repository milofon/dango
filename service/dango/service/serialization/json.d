/**
 * Модуль сериализатора JSON
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serialization.json;

private
{
    import std.algorithm.searching : startsWith;
    import std.base64 : Base64;

    import vibe.data.json;

    import dango.system.component;
    import dango.service.types;
    import dango.service.serialization.core;
}



class JsonSerializer : BaseSerializer!"JSON"
{
    UniNode deserialize(Bytes bytes)
    {
        auto strData = cast(string)bytes;
        Json json = parseJson(strData);
        return toUniNode(json);
    }


    Bytes serialize(UniNode node)
    {
        Json json = fromUniNode(node);
        return cast(Bytes)json.toString();
    }
}



class JsonSerializerFactory : BaseSerializerFactory!JsonSerializer
{
    override JsonSerializer create(Properties config)
    {
        return new JsonSerializer();
    }
}


private:


UniNode toUniNode(Json input)
{
    UniNode convert(Json node)
    {
        switch(node.type) with (Json)
        {
            case Type.undefined:
            case Type.null_:
                return UniNode();
            case Type.bool_:
                return UniNode(node.get!bool);
            case Type.int_:
            case Type.bigInt:
                return UniNode(node.get!long);
            case Type.float_:
                return UniNode(node.get!double);
            case Type.string:
                string val = node.get!string;
                if (val.startsWith("base64:"))
                    return UniNode(Base64.decode(val[7..$]));
                else
                    return UniNode(val);
            case Type.array:
            {
                UniNode[] arr = new UniNode[](node.length);
                foreach(i, Json ch; node.get!(Json[]))
                    arr[i] = convert(ch);
                return UniNode(arr);
            }
            case Type.object:
            {
                UniNode[string] map;
                foreach(string key, Json ch; node)
                    map[key] = convert(ch);
                return UniNode(map);
            }
            default:
                return UniNode();
        }
    }

    return convert(input);
}



Json fromUniNode(UniNode input)
{
    Json convert(UniNode node)
    {
        switch(node.type) with (UniNode)
        {
            case Type.nil:
                return Json();
            case Type.boolean:
                return Json(node.get!bool);
            case Type.signed:
                return Json(node.get!long);
            case Type.unsigned:
                return Json(node.get!ulong);
            case Type.floating:
                return Json(node.get!double);
            case Type.raw:
                string result = "base64:" ~ Base64.encode(node.get!(ubyte[])).idup;
                return Json(result);
            case Type.text:
                return Json(node.get!string);
            case Type.array:
            {
                Json arr = Json.emptyArray();
                foreach(UniNode ch; node.get!(UniNode[]))
                    arr ~= convert(ch);
                return arr;
            }
            case Type.object:
            {
                Json map = Json.emptyObject();
                foreach(string key, UniNode ch; node.get!(UniNode[string]))
                    map[key] = convert(ch);
                return map;
            }
            default:
                return Json();
        }
    }

    return convert(input);
}

