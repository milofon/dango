/**
 * Основной модуль сериализатора
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serializer.core;

private
{
    import std.algorithm.comparison : max;
    import std.traits : isSigned, isUnsigned, isBoolean,
           isNumeric, isFloatingPoint;
    import std.format : fmt = format;
    import std.array : appender;
    import std.exception : enforceEx;
    import std.conv : to;

    import vibe.data.serialization :
        vSerialize = serialize,
        vDeserialize = deserialize;
}


/**
 * Основной класс сериализатор
 */
abstract class Serializer
{
    /**
     * Преобразует объекты языка в UniNode
     * Params:
     * object = Объект для преобразования
     * Return: UniNode
     */
    UniNode marshal(T)(T object)
    {
        return vSerialize!(UniNodeSerializer, T)(object);
    }

    /**
     * Преобразует UniNode в объекты языка
     * Params:
     * object = UniNode
     * Return: T
     */
    T unmarshal(T)(UniNode node)
    {
        return vDeserialize!(UniNodeSerializer, T, UniNode)(node);
    }

    /**
     * Десериализация массива байт в UniNode
     * Params:
     * bytes = Массив байт
     * Return: UniNode
     */
    UniNode deserialize(ubyte[] bytes);

    /**
     * Сериализация UniNode в массив байт
     * Params:
     * node = Данные в UniNode
     * Return: массив байт
     */
    ubyte[] serialize(UniNode node);
}


/**
 * Универсальная структура для хранения данных
 */
struct UniNode
{
    enum Type
    {
        nil,
        boolean,
        unsigned,
        signed,
        floating,
        text,
        raw,
        array,
        object
    }


    this(typeof(null))
    {
        _type = Type.nil;
    }


    this(bool v)
    {
        _type = Type.boolean;
        _boolean = v;
    }


    this(T)(T v) if(isSigned!T && !isFloatingPoint!T)
    {
        _type = Type.signed;
        _signed = cast(long)v;
    }


    this(T)(T v) if (isUnsigned!T && !isFloatingPoint!T)
    {
        _type = Type.unsigned;
        _unsigned = cast(ulong)v;
    }


    this(T)(T v) if (isFloatingPoint!T)
    {
        _type = Type.floating;
        _floating = cast(double)v;
    }


    this(ubyte[] v)
    {
        _type = Type.raw;
        _raw = v;
    }


    this(string v)
    {
        _type = Type.text;
        _text = v;
    }

    this(UniNode[] v)
    {
        _type = Type.array;
        _array = v;
    }


    this(UniNode[string] v)
    {
        _type = Type.object;
        _object = v;
    }


    static UniNode emptyObject() @property
    {
        return UniNode(cast(UniNode[string])null);
    }


    static UniNode emptyArray() @property
    {
        return UniNode(cast(UniNode[])null);
    }


    Type type() const @safe @property
    {
        return _type;
    }


    /**
     * Returns the type id corresponding to the given D type.
     */
    static Type typeId(T)() @property
    {
        static if( is(T == typeof(null)) ) return Type.nil;
        else static if( is(T == bool) ) return Type.boolean;
        else static if( is(T == double) ) return Type.floating;
        else static if( is(T == float) ) return Type.floating;
        else static if( isNumeric!T && isSigned!T ) return Type.signed;
        else static if( isNumeric!T && isUnsigned!T ) return Type.unsigned;
        else static if( is(T : ubyte[]) ) return Type.raw;
        else static if( is(T == string) ) return Type.text;
        else static if( is(T == UniNode[]) ) return Type.array;
        else static if( is(T == UniNode[string]) ) return Type.object;
        else static assert(false, "Unsupported UniNode type '"~T.stringof
                ~"'. Only bool, long, double, string, ubyte[], UniNode[] and UniNode[string] are allowed.");
    }


    inout(T) get(T)() @property inout @trusted
    {
        static if (is(T == string) || is(T == ubyte[]))
            checkType!(T, ubyte[])();
        else static if(isNumeric!T && (isSigned!T || isUnsigned!T))
            checkType!(long, ulong)();
        else
            checkType!T();

        static if (is(T == bool)) return _boolean;
        else static if (is(T == double)) return _floating;
        else static if (is(T == float)) return cast(T)_floating;
        else static if (isSigned!T) return cast(T)_signed;
        else static if (isUnsigned!T) return cast(T)_unsigned;
        else static if (is(T == string))
            return _type == Type.text ? cast(T)_text : cast(T)_raw;
        else static if (is(T == ubyte[])) return cast(inout(T))_raw;
        else static if (is(T == UniNode[])) return _array;
        else static if (is(T == UniNode[string])) return _object;
    }


    inout(UniNode)* opBinaryRight(string op)(string other) inout if(op == "in")
    {
        checkType!(UniNode[string])();
        auto pv = other in _object;
        if (!pv)
            return null;
        if (pv.type == Type.nil)
            return null;
        return pv;
    }


    ref inout(UniNode) opIndex(size_t idx) inout
    {
        checkType!(UniNode[])();
        return _array[idx];
    }


    ref UniNode opIndex(string key)
    {
        checkType!(UniNode[string])();
        if (auto pv = key in _object)
            return *pv;

        _object[key] = UniNode();
        return _object[key];
    }

private :

    enum _size = max((ulong.sizeof + (void*).sizeof), 2);
    void[_size] _data = (void[_size]).init;

    static assert(_data.offsetof == 0, "m_data must be the first struct member.");


    ref inout(T) getDataAs(T)() inout @trusted
    {
        static assert(T.sizeof <= _data.sizeof);
        return (cast(inout(T)[1])_data[0 .. T.sizeof])[0];
    }


    @property ref inout(bool) _boolean() inout
    {
        return getDataAs!bool();
    }


    @property ref inout(long) _signed() inout
    {
        return getDataAs!long();
    }


    @property ref inout(ulong) _unsigned() inout
    {
        return getDataAs!ulong();
    }


    @property ref inout(double) _floating() inout
    {
        return getDataAs!double();
    }

    @property ref inout(UniNode[]) _array() inout
    {
        return getDataAs!(UniNode[])();
    }


    @property ref inout(UniNode[string]) _object() inout
    {
        return getDataAs!(UniNode[string])();
    }


    @property ref inout(ubyte[]) _raw() inout
    {
        return getDataAs!(ubyte[])();
    }


    @property ref inout(string) _text() inout
    {
        return getDataAs!(string)();
    }


    void checkType(TYPES...)(string op = null) const
    {
        bool matched = false;
        foreach (T; TYPES)
        {
            if (_type == typeId!T)
                matched = true;
        }

        if (matched)
            return;

        string expected;
        static if (TYPES.length == 1)
            expected = typeId!(TYPES[0]).to!string;
        else
        {
            foreach (T; TYPES)
            {
                if (expected.length > 0)
                    expected ~= ", ";
                expected ~= typeId!T.to!string;
            }
        }

        string name = "UniNode of type " ~ _type.to!string;
        if (!op.length)
            throw new UniNodeException("Got %s, expected %s.".fmt(name, expected));
        else
            throw new UniNodeException("Got %s, expected %s for %s.".fmt(name, expected, op));
    }


    Type _type = Type.nil;
}



struct UniNodeSerializer
{
    enum isSupportedValueType(T) = is(T == typeof(null))
                || is(T == double) || is(T == float)
                || isBoolean!T
                || is (T == ubyte[])
                || (isNumeric!T && (isSigned!T || isUnsigned!T))
                || is(T == string)
                || is(T == UniNode);

    private
    {
        UniNode _current;
        UniNode[] _stack;
    }


    @disable this(this);


    this(UniNode data) @safe
    {
        _current = data;
    }


    // serialization
    UniNode getSerializedResult()
    {
        return _current;
    }


    void beginWriteDictionary(TypeTraits)()
    {
        _stack ~= UniNode.emptyObject();
    }


    void endWriteDictionary(TypeTraits)()
    {
        _current = _stack[$-1];
        _stack.length--;
    }


    void beginWriteDictionaryEntry(ElementTypeTraits)(string name) {}


    void endWriteDictionaryEntry(ElementTypeTraits)(string name)
    {
        _stack[$-1][name] = _current;
    }


    void beginWriteArray(TypeTraits)(size_t length)
    {
        _stack ~= UniNode.emptyArray();
    }


    void endWriteArray(TypeTraits)()
    {
        _current = _stack[$-1];
        _stack.length--;
    }


    void beginWriteArrayEntry(ElementTypeTraits)(size_t index) {}


    void endWriteArrayEntry(ElementTypeTraits)(size_t index) {}


    void writeValue(TypeTraits, T)(T value) if (!is(T == UniNode))
    {
        _current = UniNode(value);
    }


    // deserialization
    void readDictionary(TypeTraits)(scope void delegate(string) entry_callback)
    {
        enforceUniNode(_current.type == UniNode.Type.object, "Expected UniNode object");
        auto old = _current;
        foreach (string key, value; _current.get!(UniNode[string]))
        {
            _current = value;
            entry_callback(key);
        }
        _current = old;
    }


    void beginReadDictionaryEntry(ElementTypeTraits)(string) {}


    void endReadDictionaryEntry(ElementTypeTraits)(string) {}


    void readArray(TypeTraits)(scope void delegate(size_t) size_callback, scope void delegate() entry_callback)
    {
        enforceUniNode(_current.type == UniNode.Type.array, "Expected JSON array");
        auto old = _current;
        UniNode[] arr = old.get!(UniNode[]);
        size_callback(arr.length);
        foreach (ent; arr)
        {
            _current = ent;
            entry_callback();
        }
        _current = old;
    }


    void beginReadArrayEntry(ElementTypeTraits)(size_t index) {}


    void endReadArrayEntry(ElementTypeTraits)(size_t index) {}


    T readValue(TypeTraits, T)() @safe
    {
        static if (is(T == UniNode))
            return _current;
        else static if (is(T == float) || is(T == double))
        {
            switch (_current.type)
            {
                default:
                    return cast(T)_current.get!long;
                case UniNode.Type.nil:
                    goto case;
                case UniNode.Type.floating:
                    return cast(T)_current.get!double;
            }
        }
        else
            return _current.get!T();
    }


    bool tryReadNull(TypeTraits)()
    {
        return _current.type == UniNode.Type.nil;
    }
}


class UniNodeException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}


alias enforceUniNode = enforceEx!UniNodeException;

