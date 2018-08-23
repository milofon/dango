/**
 * Модуль генерации документации
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-31
 */

module dango.service.protocol.rpc.schema.recorder;

private
{
    import std.algorithm.sorting : sort;
    import std.algorithm.iteration : uniq;
    import std.range.primitives : isOutputRange;
    import std.algorithm.searching : canFind;
    import std.array : Appender, array;
    import std.traits;
    import std.meta;
    import std.conv : to;
    import std.typecons : Nullable;

    import uninode.serialization : serializeToUniNode;

    import vibe.data.serialization : isISOExtStringSerializable,
                DefaultPolicy, OptionalAttribute;
    import dango.service.protocol.rpc.schema.parser : parseDocumentationContent;

    import dango.system.traits;
    import dango.service.protocol.rpc.schema.types;
}


class SchemaRecorder
{
    private
    {
        Appender!(MethodSchema[]) _methods;
        Appender!(ModelSchema[]) _models;
        Appender!(EnumSchema[]) _enums;
    }


    void registerSchema(IType, string name, alias Member)()
    {
        generateMethodSchema!(IType, name, Member)(_methods);
        generateMethodParameterSchema!(Member)(_models, _enums);
    }


    MethodSchema[] getMethods()
    {
        return _methods.data;
    }


    EnumSchema[] getEnums()
    {
        return _enums.data
            .sort!((a, b) => a.name > b.name)
            .uniq!((a, b) => a.name == b.name)
            .array;
    }


    ModelSchema[] getModels()
    {
        return _models.data
            .sort!((a, b) => a.name > b.name)
            .uniq!((a, b) => a.name == b.name)
            .array;
    }
}


private:


void generateMethodSchema(IType, string name, alias Member, Sink)(ref Sink sink)
    if (isOutputRange!(Sink, MethodSchema))
{
    alias ParameterIdents = ParameterIdentifierTuple!Member;
    alias ParameterTypes = ParameterTypeTuple!Member;
    alias ParameterDefs = ParameterDefaults!Member;
    alias RT = ReturnType!Member;

    MethodSchema ret;
    ret.name = name;

    ret.retType.type = getTypeSchema!RT;

    foreach (i, T; ParameterTypes)
    {
        enum pName = ParameterIdents[i];
        MemberSchema param;
        param.type = getTypeSchema!T;

        alias def = ParameterDefs[i];
        static if (!is(def == void))
        {
            param.defVal = marshalObject(def);
            param.required = false;
        }
        else
            param.required = true;

        ret.params[pName] = param;
    }

    enum annotations = getUDAs!(Member, Doc);
    static if (annotations.length)
    {
        enum content = annotations[0].content;
        parseDocumentationContent(ret, content);
    }

    sink.put(ret);
}



void generateMethodParameterSchema(alias Member, MSink, ESink)(ref MSink mSink, ref ESink eSink)
    if (isOutputRange!(MSink, ModelSchema) && isOutputRange!(ESink, EnumSchema))
{
    alias RT = ReturnType!Member;

    foreach (T; ParameterTypeTuple!Member)
        generateModelFieldSchema!T(mSink, eSink);

    generateModelFieldSchema!RT(mSink, eSink);
}



void generateModelFieldSchema(Model, MSink, ESink)(ref MSink mSink, ref ESink eSink)
    if (isOutputRange!(MSink, ModelSchema) && isOutputRange!(ESink, EnumSchema))
{
    foreach(IModel; InternalTypes!Model)
    {
        static if (is(IModel == enum))
            generateModelEnumSchema!(IModel, ESink)(eSink);
        else static if (isCompositeType!IModel)
            generateModelCompositeSchema!(IModel, MSink, ESink)(mSink, eSink);
    }
}



void generateModelEnumSchema(Model, ESink)(ref ESink eSink)
    if (isOutputRange!(ESink, EnumSchema) && is(Model == enum))
{
    alias OT = OriginalType!Model;
    EnumSchema ret;
    ret.name = Model.stringof;
    ret.type = getTypeSchema!OT;

    enum annoEnum = getUDAs!(Model, Doc);
    static if (annoEnum.length)
        ret.note = annoEnum[0].content;

    foreach(em; EnumMembers!Model)
    {
        string key = to!string(em);
        ret.values[key] = UniNode(cast(OT)em);
    }

    eSink.put(ret);
}


alias defOptional = OptionalAttribute!DefaultPolicy;


void generateModelCompositeSchema(Model, MSink, ESink)(ref MSink mSink, ref ESink eSink)
    if (isOutputRange!(MSink, ModelSchema) && isOutputRange!(ESink, EnumSchema))
{
    enum modelName = Model.stringof;

    if (mSink.data.canFind!((t) => t.name == modelName))
        return;

    ModelSchema ret;
    ret.name = modelName;

    enum annoModel = getUDAs!(Model, Doc);
    static if (annoModel.length)
        ret.note = annoModel[0].content;

    alias MemberNameTuple = FieldNameTuple!Model;

    foreach(i, MemberType; Fields!Model)
    {
        enum name = MemberNameTuple[i];
        static if (IsPublicMember!(Model, name))
        {
            MemberSchema ms;
            ms.type = getTypeSchema!MemberType;

            enum annotations = getUDAs!(__traits(getMember, Model, name), Doc);
            static if (annotations.length)
                ms.note = annotations[0].content;

            static if (hasUDA!(__traits(getMember, Model, name), defOptional))
                ms.required = false;
            else
                ms.required = true;

            ret.members[name] = ms;
        }
    }

    mSink.put(ret);

    foreach(i, MemberType; Fields!Model)
    {
        enum name = MemberNameTuple[i];
        static if (IsPublicMember!(Model, name))
            generateModelFieldSchema!(MemberType, MSink, ESink)(mSink, eSink);
    }
}



template InternalTypes(T)
{
    static if (isArray!T)
        alias InternalTypes = AliasSeq!(Unqual!(ForeachType!T));
    else static if (isAssociativeArray!T)
        alias InternalTypes = AliasSeq!(
                Unqual!(ForeachType!T),
                Unqual!(KeyType!T));
    else static if (isInstanceOf!(Nullable, T))
        alias InternalTypes = TemplateArgsOf!T;
    else
        alias InternalTypes = AliasSeq!(Unqual!T);
}



template isCompositeType(T)
{
    enum isCompositeType = isAggregateType!T
        && !is(T == UniNode) && !isISOExtStringSerializable!T;
}



TypeSchema getTypeSchema(T)()
{
    TypeSchema ret;
    ret.original = TypeSchemaReal!T;
    ret.input = TypeSchemaInput!T;

    static if (isSomeString!T)
    {
        TypeSchemaDetail dt;
        dt.kind = TypeSchemaDetailType!T;
        dt.name = TypeSchemaReal!T;
        ret.details ~= dt;
    }
    else
        foreach(IT; InternalTypes!T)
        {
            TypeSchemaDetail dt;
            dt.kind = TypeSchemaDetailType!IT;
            dt.name = TypeSchemaReal!IT;
            ret.details ~= dt;
        }

    return ret;
}



template TypeSchemaReal(T)
{
    enum TypeSchemaReal = T.stringof;
}



template TypeSchemaDetailType(T)
{
    static if (is(T == enum))
        enum TypeSchemaDetailType = "enum";
    else static if (isCompositeType!T)
        enum TypeSchemaDetailType = "model";
    else
        enum TypeSchemaDetailType = "primitive";
}



template TypeSchemaInput(T)
{
    static if (isNumeric!T)
        enum TypeSchemaInput = "number";
    else static if (isSomeString!T || isISOExtStringSerializable!T)
        enum TypeSchemaInput = "string";
    else static if (isArray!T)
        enum TypeSchemaInput = "array";
    else static if (isAssociativeArray!T)
        enum TypeSchemaInput = "object";
    else static if (is(T == bool))
        enum TypeSchemaInput = "boolean";
    else static if (is(T == UniNode))
        enum TypeSchemaInput = "any";
    else
        enum TypeSchemaInput = T.stringof;
}

