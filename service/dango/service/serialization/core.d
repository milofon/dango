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
    import core.exception : AssertError;

    import std.algorithm.comparison : max;
    import std.traits : isSigned, isUnsigned, isBoolean,
           isNumeric, isFloatingPoint, isArray, ForeachType,
           isStaticArray, Unqual, isSomeString, isAssociativeArray, KeyType;
    import std.format : fmt = format;
    import std.exception : enforce;
    import std.array : appender;
    import std.variant : maxSize;
    import std.conv : to;

    import vibe.data.serialization :
        vSerialize = serialize,
        vDeserialize = deserialize;

    import dango.system.container;
    import dango.service.types;
}


/**
 * Основной интерфейс сериализатор
 */
interface Serializer : Named
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
 * Базовый сериализатор
 */
abstract class BaseSerializer(string N) : Serializer
{
    mixin NamedMixin!N;
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


private template TypeEnum(U)
{
	import std.array : join;
	import std.traits : FieldNameTuple;
	mixin("enum TypeEnum { " ~ [FieldNameTuple!U].join(", ") ~ " }");
}


/**
 * Универсальная структура для хранения данных
 */
struct UniNode
{
@safe:
    private
    {
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

        struct SizeChecker
        {
            int function() fptr;
            ubyte[maxSize!U] data;
        }

        enum size = SizeChecker.sizeof - (int function()).sizeof;

        union
        {
            ubyte[size] _store;
            // conservatively mark the region as pointers
            static if (size >= (void*).sizeof)
                void*[size / (void*).sizeof] p;
        }

        Kind _kind;

        ref inout(T) getDataAs(T)() inout @trusted {
            static assert(T.sizeof <= _store.sizeof);
            return (cast(inout(T)[1])_store[0 .. T.sizeof])[0];
        }

        @property ref inout(UniNode[string]) _object() inout
        {
            return getDataAs!(UniNode[string])();
        }

        @property ref inout(UniNode[]) _array() inout
        {
            return getDataAs!(UniNode[])();
        }

        @property ref inout(bool) _bool() inout
        {
            return getDataAs!bool();
        }

        @property ref inout(long) _int() inout
        {
            return getDataAs!long();
        }

        @property ref inout(ulong) _uint() inout
        {
            return getDataAs!ulong();
        }

        @property ref inout(real) _float() inout
        {
            return getDataAs!real();
        }

        @property ref inout(string) _string() inout
        {
            return getDataAs!string();
        }

        @property ref inout(ubyte[]) _raw() inout
        {
            return getDataAs!(ubyte[])();
        }
    }


    alias Kind = TypeEnum!U;


    Kind kind() @property
    {
        return _kind;
    }


    static UniNode emptyObject() @property
    {
        return UniNode(cast(UniNode[string])null);
    }


    this(UniNode[string] val)
    {
        _kind = Kind.object;
        _object = val;
    }


    unittest
    {
        auto node = UniNode.emptyObject;
        assert(node.kind == Kind.object);
    }


    static UniNode emptyArray() @property
    {
        return UniNode(cast(UniNode[])null);
    }


    this(UniNode[] val)
    {
        _kind = Kind.array;
        _array = val;
    }


    unittest
    {
        auto node = UniNode.emptyArray;
        assert(node.kind == Kind.array);
    }


    inout(UniNode)* opBinaryRight(string op)(string key) inout if (op == "in")
    {
        enforceUniNode(_kind == Kind.object, "Expected UniNode object");
        return key in _object;
    }


    unittest
    {
        auto node = UniNode(1);
        auto mnode = UniNode(["one": node, "two": node]);
        assert (mnode.kind == Kind.object);
        assert("one" in mnode);
    }


    this(typeof(null))
    {
        _kind = Kind.nil;
    }


    unittest
    {
        auto node = UniNode(null);
        assert (node.kind == Kind.nil);
        auto node2 = UniNode();
        assert (node2.kind == Kind.nil);
    }


    this(T)(T val) if (isBoolean!T)
    {
        _kind = Kind.boolean;
        _bool = val;
    }


    unittest
    {
        auto node = UniNode(false);
        assert (node.kind == Kind.boolean);
        assert (node.get!bool == false);

        auto nodei = UniNode(0);
        assert (nodei.kind == Kind.integer);
    }


    this(T)(T val) if (isUnsignedNumeric!T)
    {
        _kind = Kind.uinteger;
        _uint = val;
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(ubyte, ushort, uint, ulong))
        {
            TT v = cast(TT)11U;
            auto node = UniNode(v);
            assert (node.kind == Kind.uinteger);
            assert (node.get!TT == cast(TT)11U);
        }
    }


    this(T)(T val) if (isSignedNumeric!T)
    {
        _kind = Kind.integer;
        _int = val;
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(byte, short, int, long))
        {
            TT v = -11;
            auto node = UniNode(v);
            assert (node.kind == Kind.integer);
            assert (node.get!TT == cast(TT)-11);
        }
    }


    this(T)(T val) if (isFloatingPoint!T)
    {
        _kind = Kind.floating;
        _float = val;
    }


    unittest
    {
        import std.meta : AliasSeq;
        foreach (TT; AliasSeq!(float, double))
        {
            TT v = 11.11;
            auto node = UniNode(v);
            assert (node.kind == Kind.floating);
            assert (node.get!TT == cast(TT)11.11);
        }
    }


    this(T)(T val) if(isSomeString!T)
    {
        _kind = Kind.text;
        _string = val;
    }


    unittest
    {
        string str = "hello";
        auto node = UniNode(str);
        assert(node.kind == Kind.text);
        assert (node.get!(string) == "hello");
    }


    this(T)(T val) if (isRawData!T)
    {
        _kind = Kind.raw;
        static if (isStaticArray!T)
            _raw = val.dup;
        else
            _raw = val;
    }


    unittest
    {
        ubyte[] dynArr = [1, 2, 3];
        auto node = UniNode(dynArr);
        assert (node.kind == Kind.raw);
        assert (node.get!(ubyte[]) == [1, 2, 3]);

        ubyte[3] stArr = [1, 2, 3];
        node = UniNode(stArr);
        assert (node.kind == Kind.raw);
        assert (node.get!(ubyte[3]) == [1, 2, 3]);
    }


    unittest
    {
        auto node = UniNode();
        assert (node.kind == Kind.nil);

        auto anode = UniNode([node, node]);
        assert (anode.kind == Kind.array);

        auto mnode = UniNode(["one": node, "two": node]);
        assert (mnode.kind == Kind.object);
    }


    void appendArrayElement(UniNode element)
    {
        enforceUniNode(_kind == Kind.array,
                "'appendArrayElement' only allowed for array types, not "
                ~.to!string(_kind)~".");
        _array ~= element;
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
        try {
            static if (isSignedNumeric!T)
            {
                checkType!T(Kind.integer);
                return cast(T)(_int);
            }
            else static if (isUnsignedNumeric!T)
            {
                checkType!T(Kind.uinteger);
                return cast(T)(_uint);
            }
            else static if (isFloatingPoint!T)
            {
                checkType!T(Kind.floating);
                return cast(T)(_float);
            }
            else static if (isRawData!T)
            {
                checkType!T(Kind.raw);
                if (_kind == Kind.nil)
                    return inout(T).init;

                static if (isStaticArray!T)
                    return cast(inout(T))_raw[0..T.length];
                else
                    return cast(inout(T))_raw;
            }
            else static if (isSomeString!T)
            {
                checkType!T(Kind.text);
                if (_kind == Kind.nil)
                    return "";
                else
                    return _string;
            }
            else static if (isBoolean!T)
            {
                checkType!T(Kind.boolean);
                return _bool;
            }
            else static if (isArray!T && is(ForeachType!T == UniNode))
            {
                checkType!T(Kind.array);
                return _array;
            }
            else static if (isAssociativeArray!T
                    && is(ForeachType!T == UniNode) && is(KeyType!T == string))
            {
                checkType!T(Kind.object);
                return _object;
            }
            else
                throw new UniNodeException(
                        fmt!("Trying to get %s but have %s.")(T.stringof, _kind));
        }
        catch (Throwable e)
            throw new UniNodeException(e.msg, e.file, e.line, e.next);
    }


    int opApply(int delegate(ref string idx, ref UniNode obj) @safe dg)
    {
        enforceUniNode(_kind == Kind.object, "Expected UniNode object");
        foreach (idx, ref v; _object)
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
        assert (mnode.kind == Kind.object);

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
        enforceUniNode(_kind == Kind.array, "Expected UniNode array");
        foreach (ref v; _array)
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
        assert (mnode.kind == Kind.array);

        UniNode[] nodes;
        foreach (ref UniNode node; mnode)
            nodes ~= node;

        assert(nodes.length == 2);
    }


    size_t length() @property
    {
        switch (_kind) with (Kind)
        {
            case text:
                return _string.length;
            case raw:
                return _raw.length;
            case array:
                return _array.length;
            case object:
                return _object.length;
            default:
                enforceUniNode(false, "Expected UniNode not length");
        }
        return 0;
    }


    bool opEquals(ref UniNode other)
    {
        if (_kind != other.kind)
            return false;

        final switch (_kind) with (Kind)
        {
            case nil:
                return true;
            case boolean:
                return _bool == other._bool;
            case uinteger:
                return _uint == other._uint;
            case integer:
                return _int == other._int;
            case floating:
                return _float == other._float;
            case text:
                return _string == other._string;
            case raw:
                return _raw == other._raw;
            case array:
                return _array == other._array;
            case object:
                return _object == other._object;
        }
    }


    ref inout(UniNode) opIndex(size_t idx) inout
    {
        enforceUniNode(_kind == Kind.array, "Expected UniNode array");
        return _array[idx];
    }


    ref UniNode opIndex(string key)
    {
        enforceUniNode(_kind == Kind.object, "Expected UniNode object");
        return _object[key];
    }


    ref UniNode opIndexAssign(ref UniNode val, string key)
    {
        enforceUniNode(_kind == Kind.object, "Expected UniNode object");
        return _object[key] = val;
    }


    string toString()
    {
        auto buff = appender!string;

        void fun(ref UniNode node) @safe
        {
            switch (node.kind)
            {
                case Kind.nil:
                    buff.put("nil");
                    break;
                case Kind.boolean:
                    buff.put("bool("~node.get!bool.to!string~")");
                    break;
                case Kind.uinteger:
                    buff.put("unsigned("~node.get!ulong.to!string~")");
                    break;
                case Kind.integer:
                    buff.put("signed("~node.get!long.to!string~")");
                    break;
                case Kind.floating:
                    buff.put("floating("~node.get!double.to!string~")");
                    break;
                case Kind.text:
                    buff.put("text("~node.get!string.to!string~")");
                    break;
                case Kind.raw:
                    buff.put("raw("~node.get!(ubyte[]).to!string~")");
                    break;
                case Kind.object:
                {
                    buff.put("{");
                    size_t len = node.length;
                    size_t count;
                    foreach (ref string k, ref UniNode v; node)
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
                case Kind.array:
                {
                    buff.put("[");
                    size_t len = node.length;
                    foreach (i, v; node.get!(UniNode[]))
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


private:


    void checkType(T)(Kind target) inout
    {
        enforceUniNode(_kind == target,
                fmt!("Trying to get %s but have %s.")(T.stringof, _kind));
    }
}



struct UniNodeSerializer
{
    template isUniNodeType(T)
    {
        enum isUniNodeType = isNumeric!T || isBoolean!T || isSomeString!T  || is(T == typeof(null)) || isRawData!T;
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
                case UniNode.Kind.nil:
                    return T.nan;
                case UniNode.Kind.floating:
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

