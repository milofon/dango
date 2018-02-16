/**
 * Основной модуль сериализатора
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.serializer.core;


public
{
    import proped : Properties;
}


private
{
    import std.algorithm.comparison : max;
    import std.traits : isSigned, isUnsigned, isBoolean,
           isNumeric, isFloatingPoint, isArray, ForeachType,
           isStaticArray;
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
     * Сериализация объекта языка в массив байт
     * Params:
     * object = Объект для преобразования
     * Return: массив байт
     */
    ubyte[] serializeObject(T)(T object)
    {
        return serialize(marshalObject!T(object));
    }

    /**
     * Десериализация массива байт в объект языка
     * Params:
     * bytes = Массив байт
     * Return: T
     */
    T deserializeObject(T)(ubyte[] bytes)
    {
        return unmarshalObject!T(deserialize(bytes));
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

    /**
     * Инициализация сериализатора при помощи
     * объекта настроек
     * Params:
     * config = Объект настроек
     */
    void initialize(Properties config);
}


/**
 * Преобразует объекты языка в UniNode
 * Params:
 * object = Объект для преобразования
 * Return: UniNode
 */
UniNode marshalObject(T)(T object)
{
    return vSerialize!(UniNodeSerializer, T)(object);
}


/**
 * Преобразует UniNode в объекты языка
 * Params:
 * object = UniNode
 * Return: T
 */
T unmarshalObject(T)(UniNode node)
{
    return vDeserialize!(UniNodeSerializer, T, UniNode)(node);
}


/**
 * Проверка на целочисленное знаковое число
 */
template isSignedNumeric(T)
{
    enum isSignedNumeric = isNumeric!T && isSigned!T && !isFloatingPoint!T;
}


/**
 * Проверка на целочисленное без знвковое число
 */
template isUnsignedNumeric(T)
{
    enum isUnsignedNumeric = isNumeric!T && isUnsigned!T && !isFloatingPoint!T;
}


/**
 * Проверка на соотвествие бинарным данным
 */
template isRawData(T)
{
    enum isRawData = isArray!T && is(ForeachType!T == ubyte);
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


    union Via
    {
        bool boolean;
        ulong uinteger;
        long integer;
        real floating;
        ubyte[] raw;
        UniNode[] array;
        UniNode[string] map;
    }


    Via via;
    Type type;


    this(Type type)
    {
        this.type = type;
    }


    this(typeof(null))
    {
        this(Type.nil);
    }


    unittest
    {
        auto node = UniNode();
        assert (node.type == Type.nil);
    }


    this(bool value)
    {
        this(Type.boolean);
        via.boolean = value;
    }


    unittest
    {
        auto node = UniNode(false);
        assert (node.type == Type.boolean);
        assert (node.get!bool == false);
    }


    this(T)(T value) if (isSignedNumeric!T)
    {
        this(Type.signed);
        via.uinteger = value;
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(byte, short, int, long))
        {
            TT v = -11;
            auto node = UniNode(v);
            assert (node.type == Type.signed);
            assert (is (typeof(node.get!TT) == TT));
            assert (node.get!TT == -11);
        }
    }


    this(T)(T value) if (isUnsignedNumeric!T)
    {
        this(Type.unsigned);
        via.uinteger = value;
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(ubyte, ushort, uint, ulong))
        {
            TT v = 11;
            auto node = UniNode(v);
            assert (node.type == Type.unsigned);
            assert (is (typeof(node.get!TT) == TT));
            assert (node.get!TT == 11);
        }
    }


    this(T)(T value) if (isFloatingPoint!T)
    {
        this(Type.floating);
        via.floating = value;
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(float, double))
        {
            TT v = 11.11;
            auto node = UniNode(v);
            assert (node.type == Type.floating);
            assert (is (typeof(node.get!TT) == TT));
            assert (node.get!TT == cast(TT)11.11);
        }
    }


    this(T)(T value) if (isRawData!T)
    {
        this(Type.raw);
        static if (isStaticArray!T)
            via.raw = value.dup;
        else
            via.raw = value;
    }


    unittest
    {
        ubyte[] dynArr = [1, 2, 3];
        auto node = UniNode(dynArr);
        assert (node.type == Type.raw);
        assert (is(typeof(node.get!(ubyte[])) == ubyte[]));
        assert (node.get!(ubyte[]) == [1, 2, 3]);

        ubyte[3] stArr = [1, 2, 3];
        node = UniNode(stArr);
        assert (node.type == Type.raw);
        assert (is(typeof(node.get!(ubyte[3])) == ubyte[3]));
        assert (node.get!(ubyte[3]) == [1, 2, 3]);
    }


    this(string value)
    {
        this(Type.text);
        via.raw = cast(ubyte[])value;
    }


    unittest
    {
        string str = "hello";
        auto node = UniNode(str);
        assert(node.type == Type.text);
        assert (is(typeof(node.get!(string)) == string));
        assert (node.get!(string) == "hello");
    }


    this(UniNode[] value)
    {
        this(Type.array);
        via.array = value;
    }


    this(UniNode[string] value)
    {
        this(Type.object);
        via.map = value;
    }


    static UniNode emptyObject() @property
    {
        return UniNode(cast(UniNode[string])null);
    }


    static UniNode emptyArray() @property
    {
        return UniNode(cast(UniNode[])null);
    }


    static Type typeId(T)() @property
    {
        static if( is(T == typeof(null)) ) return Type.nil;
        else static if( is(T == bool) ) return Type.boolean;
        else static if( isFloatingPoint!T ) return Type.floating;
        else static if( isSignedNumeric!T ) return Type.signed;
        else static if( isUnsignedNumeric!T ) return Type.unsigned;
        else static if( isRawData!T ) return Type.raw;
        else static if( is(T == string) ) return Type.text;
        else static if( is(T == UniNode[]) ) return Type.array;
        else static if( is(T == UniNode[string]) ) return Type.object;
        else static assert(false, "Unsupported UniNode type '"~T.stringof
                ~"'. Only bool, long, ulong, double, string, ubyte[], UniNode[] and UniNode[string] are allowed.");
    }


    inout(T) get(T)() @property inout @trusted
    {
        static if (is(T == string) || isRawData!T)
            checkType!(T, ubyte[], typeof(null))();
        else static if(isNumeric!T && (isSigned!T || isUnsigned!T) && !isFloatingPoint!T)
            checkType!(long, ulong)();
        else
            checkType!T();

        static if (is(T == bool)) return via.boolean;
        else static if (is(T == double)) return via.floating;
        else static if (is(T == float)) return cast(T)via.floating;
        else static if (isSigned!T) return cast(T)via.integer;
        else static if (isUnsigned!T) return cast(T)via.uinteger;
        else static if (is(T == string))
        {
            if (type == Type.nil)
                return "";
            else
                return cast(T)via.raw;
        }
        else static if (isRawData!T)
        {
            if (type == Type.nil)
            {
                T ret;
                return cast(inout(T))ret;
            }
            static if (isStaticArray!T)
                return cast(inout(T))via.raw[0..T.length];
            else
                return cast(inout(T))via.raw;
        }
        else static if (is(T == UniNode[])) return via.array;
        else static if (is(T == UniNode[string])) return via.map;
    }


    ref inout(UniNode) opIndex(size_t idx) inout
    {
        checkType!(UniNode[])();
        return via.array[idx];
    }


    ref UniNode opIndex(string key)
    {
        checkType!(UniNode[string])();
        if (auto pv = key in via.map)
            return *pv;

        via.map[key] = UniNode();
        return via.map[key];
    }


    void appendArrayElement(UniNode element)
    {
        enforceUniNode(type == Type.array, "'appendArrayElement' only allowed for array types, not "
                ~.to!string(type)~".");
        via.array ~= element;
    }


    string toString()
    {
        auto buff = appender!string;

        void fun(ref UniNode node)
        {
            switch (node.type)
            {
                case Type.nil:
                    buff.put("nil");
                    break;
                case Type.boolean:
                    buff.put("bool("~node.get!bool.to!string~")");
                    break;
                case Type.unsigned:
                    buff.put("unsigned("~node.get!ulong.to!string~")");
                    break;
                case Type.signed:
                    buff.put("signed("~node.get!long.to!string~")");
                    break;
                case Type.floating:
                    buff.put("floating("~node.get!double.to!string~")");
                    break;
                case Type.text:
                    buff.put("text("~node.get!string.to!string~")");
                    break;
                case Type.raw:
                    buff.put("raw("~node.get!(ubyte[]).to!string~")");
                    break;
                case Type.object:
                {
                    buff.put("{");
                    size_t len = node.via.map.length;
                    size_t count;
                    foreach (k, v; node.via.map)
                    {
                        count++;
                        buff.put(k ~ ":");
                        fun(v);
                        if (count < len)
                            buff.put(", ");
                    }
                    buff.put("}");
                    break;
                }
                case Type.array:
                {
                    buff.put("[");
                    size_t len = node.via.array.length;
                    foreach (i, v; node.via.array)
                    {
                        fun(v);
                        if (i < len)
                            buff.put(", ");
                    }
                    buff.put("]");
                    break;
                }
                default:
                    buff.put("undefined");
                    break;
            }
        }

        fun(this);
        return buff.data;
    }


private :

    void checkType(TYPES...)(string op = null) const
    {
        bool matched = false;
        foreach (T; TYPES)
        {
            if (type == typeId!T)
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

        string name = "UniNode of type " ~ type.to!string;
        if (!op.length)
            throw new UniNodeException("Got %s, expected %s.".fmt(name, expected));
        else
            throw new UniNodeException("Got %s, expected %s for %s.".fmt(name, expected, op));
    }
}



struct UniNodeSerializer
{
    enum isSupportedValueType(T) = is(T == typeof(null))
                || isFloatingPoint!T
                || isBoolean!T
                || isRawData!T
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


    void endWriteArrayEntry(ElementTypeTraits)(size_t index)
    {
        _stack[$-1].appendArrayElement(_current);
    }


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
        enforceUniNode(_current.type == UniNode.Type.array, "Expected UniNode array");
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


unittest
{
    struct FD
    {
        int a;
        ubyte[3] vector;
    }

    FD fd = FD(1, [1, 2, 3]);
    auto data = marshalObject(fd);
    assert(data.type == UniNode.Type.object);
}


class UniNodeException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}


alias enforceUniNode = enforceEx!UniNodeException;
