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
    import proped : Properties;
}

private
{
    import std.algorithm.comparison : max;
    import std.traits : isSigned, isUnsigned, isBoolean,
           isNumeric, isFloatingPoint, isArray, ForeachType,
           isStaticArray, Unqual, isSomeString;
    import std.format : fmt = format;
    import std.exception : enforce;
    import std.array : appender;
    import std.conv : to;

    import taggedalgebraic;
    import vibe.data.serialization :
        vSerialize = serialize,
        vDeserialize = deserialize;

    import dango.system.container;
    import dango.service.types;
}


/**
 * Основной интерфейс сериализатор
 */
interface Serializer
{
    /**
     * Сериализация объекта языка в массив байт
     * Params:
     * object = Объект для преобразования
     * Return: массив байт
     */
    final Bytes serializeObject(T)(T object)
    {
        return serialize(marshalObject!T(object));
    }

    /**
     * Десериализация массива байт в объект языка
     * Params:
     * bytes = Массив байт
     * Return: T
     */
    final T deserializeObject(T)(Bytes bytes)
    {
        return unmarshalObject!T(deserialize(bytes));
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


/**
 * Базовая фабрика сериализатора
 */
abstract class BaseSerializerFactory(string N) : ComponentFactory!Serializer, Named
{
    mixin NamedMixin!N;
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
    enum isRawData = isArray!T && is(Unqual!(ForeachType!T) == ubyte);
}


/**
 * Универсальная структура для хранения данных
 */
struct UniNode
{
@safe:
    union U {
        typeof(null) nil;
        bool boolean;
        ulong uinteger;
        long integer;
        real floating;
        string text;
        ubyte[] raw;
        UniNode[] array;
        UniNode[string] object;
    }

    TaggedAlgebraic!U u;
    alias u this;
    alias TAU = TaggedAlgebraic!U;


    static UniNode emptyObject() @property
    {
        return UniNode(cast(UniNode[string])null);
    }


    unittest
    {
        auto node = UniNode.emptyObject;
        assert(node.kind == TAU.Kind.object);
    }


    static UniNode emptyArray() @property
    {
        return UniNode(cast(UniNode[])null);
    }


    unittest
    {
        auto node = UniNode.emptyArray;
        assert(node.kind == TAU.Kind.array);
    }


    this(T)(T val) if (isBoolean!T)
    {
        u = TAU(cast(bool)val);
    }


    unittest
    {
        auto node = UniNode(false);
        assert (node.kind == TAU.Kind.boolean);
        assert (node.get!bool == false);

        auto nodei = UniNode(0);
        assert (nodei.kind == TAU.Kind.integer);
    }


    this(T)(T val) if (isUnsignedNumeric!T)
    {
        u = TAU(cast(ulong)val);
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(ubyte, ushort, uint, ulong))
        {
            TT v = cast(TT)11U;
            auto node = UniNode(v);
            assert (node.kind == TAU.Kind.uinteger);
            assert (node.get!TT == cast(TT)11U);
        }
    }


    this(T)(T val) if (isSignedNumeric!T)
    {
        u = TAU(cast(long)val);
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(byte, short, int, long))
        {
            TT v = -11;
            auto node = UniNode(v);
            assert (node.kind == TAU.Kind.integer);
            assert (node.get!TT == cast(TT)-11);
        }
    }


    this(T)(T val) if (isFloatingPoint!T)
    {
        u = TAU(cast(real)val);
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(float, double))
        {
            TT v = 11.11;
            auto node = UniNode(v);
            assert (node.kind == TAU.Kind.floating);
            assert (node.get!TT == cast(TT)11.11);
        }
    }


    this(T)(T val) if(isSomeString!T)
    {
        u = TAU(cast(string)val);
    }


    unittest
    {
        string str = "hello";
        auto node = UniNode(str);
        assert(node.kind == TAU.Kind.text);
        assert (node.get!(string) == "hello");
    }


    this(T)(T val) if (isRawData!T)
    {
        static if (isStaticArray!T)
            u = TAU(val.dup);
        else
            u = TAU(val);
    }


    unittest
    {
        ubyte[] dynArr = [1, 2, 3];
        auto node = UniNode(dynArr);
        assert (node.kind == TAU.Kind.raw);
        assert (node.get!(ubyte[]) == [1, 2, 3]);

        ubyte[3] stArr = [1, 2, 3];
        node = UniNode(stArr);
        assert (node.kind == TAU.Kind.raw);
        assert (node.get!(ubyte[3]) == [1, 2, 3]);
    }


    this(ARGS...)(ARGS args)
    {
        u = TaggedAlgebraic!U(args);
    }


    unittest
    {
        auto node = UniNode();
        assert (node.kind == TAU.Kind.nil);

        auto anode = UniNode([node, node]);
        assert (anode.kind == TAU.Kind.array);

        auto mnode = UniNode(["one": node, "two": node]);
        assert (mnode.kind == TAU.Kind.object);
    }


    void appendArrayElement(UniNode element)
    {
        enforceUniNode(u.kind == Kind.array,
                "'appendArrayElement' only allowed for array types, not "
                ~.to!string(u.kind)~".");
        u ~= element;
    }


    unittest
    {
        auto node = UniNode(1);
        auto anode = UniNode([node, node]);
        assert(anode.length == 2);
        anode.appendArrayElement(node);
        assert(anode.length == 3);
    }


    inout(T) get(T)() @property inout @trusted
    {
        static if (isSignedNumeric!T)
            return cast(T)(u.get!long);
        else static if (isUnsignedNumeric!T)
            return cast(T)(u.get!ulong);
        else static if (isFloatingPoint!T)
            return cast(T)(u.get!real);
        else static if (isRawData!T)
        {
            if (u.kind == TAU.Kind.nil)
                return inout(T).init;

            static if (isStaticArray!T)
                return (u.get!(ubyte[]))[0..T.length];
            else
                return u.get!(ubyte[]);
        }
        else static if (isSomeString!T)
        {
            if (u.kind == TAU.Kind.nil)
                return "";
            else
                return u.get!string;
        }
        else
            return u.get!T;
    }


    int opApply(int delegate(ref string idx, ref UniNode obj) @safe dg)
    {
        enforceUniNode(u.kind == UniNode.Kind.object, "Expected UniNode object");
        foreach (idx, ref v; get!(UniNode[string]))
        {
            if (auto ret = dg(idx, v))
                return ret;
        }
        return 0;
    }


    unittest
    {
        auto node = UniNode(1);
        auto mnode = UniNode(["one": node, "two": node]);
        assert (mnode.kind == TAU.Kind.object);

        string[] keys;
        UniNode[] nodes;
        foreach (string key, ref UniNode node; mnode)
        {
            keys ~= key;
            nodes ~= node;
        }

        assert(keys == ["two", "one"]);
        assert(nodes.length == 2);
    }


    int opApply(int delegate(ref UniNode obj) @safe dg)
    {
        enforceUniNode(u.kind == UniNode.Kind.array, "Expected UniNode array");
        foreach (ref v; get!(UniNode[]))
        {
            if (auto ret = dg(v))
                return ret;
        }
        return 0;
    }


    unittest
    {
        auto node = UniNode(1);
        auto mnode = UniNode([node, node]);
        assert (mnode.kind == TAU.Kind.array);

        UniNode[] nodes;
        foreach (ref UniNode node; mnode)
        {
            nodes ~= node;
        }

        assert(nodes.length == 2);
    }


    size_t length() @property
    {
        switch (u.kind) with (TAU.Kind)
        {
            case text:
                return u.length;
            case raw:
                return u.length;
            case array:
                return u.length;
            case object:
                return u.length;
            default:
                enforceUniNode(false, "Expected UniNode not length");
                return 0;
        }
    }


    bool opEquals(ref UniNode other)
    {
        return u == other.u;
    }
}



struct UniNodeSerializer
{
    template isUniNodeType(T)
    {
        enum isUniNodeType = isNumeric!T || isBoolean!T || isSomeString!T  || is(T == typeof(null));
    }

    enum isSupportedValueType(T) = isUniNodeType!T || is(T == UniNode);


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
    UniNode getSerializedResult() @safe
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


    void writeValue(TypeTraits, T)(UniNode value) if (is(T == UniNode))
    {
        _current = value;
    }


    // deserialization
    void readDictionary(TypeTraits)(scope void delegate(string) @safe entry_callback) @safe
    {
        auto old = _current;
        foreach (ref string key, ref UniNode value; _current)
        {
            _current = value;
            entry_callback(key);
        }
        _current = old;
    }


    void beginReadDictionaryEntry(ElementTypeTraits)(string) {}


    void endReadDictionaryEntry(ElementTypeTraits)(string) {}


    void readArray(TypeTraits)(scope void delegate(size_t) @safe size_callback,
            scope void delegate() @safe entry_callback)
    {
        auto old = _current;
        size_callback(_current.length);
        foreach (ref UniNode ent; _current)
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
            switch (_current.kind)
            {
                default:
                    return cast(T)_current.get!T;
                case UniNode.Type.nil:
                    return T.nan;
                case UniNode.Type.floating:
                    return _current.get!T;
            }
        }
        else
            return _current.get!T();
    }


    bool tryReadNull(TypeTraits)()
    {
        return _current.kind == UniNode.Kind.nil;
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
    assert(data.kind == UniNode.Kind.object);
}



class UniNodeException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}



private void enforceUniNode(string file = __FILE__, size_t line = __LINE__)(bool cond,
        lazy string message = "JSON exception") @safe
{
    () @trusted {
        enforce!UniNodeException(cond, message, file, line);
    } ();
}

