/**
 * Модуль генерации документации
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-31
 */

module dango.service.protocol.rpc.schema.traits;

private
{
    import std.algorithm.searching : canFind;
    import std.traits;
    import std.meta;
    import std.conv : to;
    import std.typecons : Nullable;

    import vibe.data.serialization : optional;

    import dango.system.traits;
    import dango.service.protocol.rpc.schema.parser : parseDocumentationContent;
    import dango.service.protocol.rpc.schema.types;
}


/**
 * Генерация документации на основе аннотации метода
 * Params:
 * IType  = Тип интерфейса контроллера
 * name   = Имя метода
 * Member = Символ метода
 */
MethodDoc generateMethodDocumentation(IType, string name, alias Member)()
{
    alias ParameterIdents = ParameterIdentifierTuple!Member;
    alias ParameterTypes = ParameterTypeTuple!Member;
    alias ParameterDefs = ParameterDefaults!Member;
    alias RT = ReturnType!Member;

    MethodDoc ret;
    ret.method = name;
    ret.retDoc.typeDoc = getFieldModelDoc!RT;

    foreach (i, T; ParameterTypes)
    {
        FieldDoc param;
        param.typeDoc = getFieldModelDoc!T;

        alias def = ParameterDefs[i];
        static if (!is(def == void))
            param.defVal = UniNode(def);

        ret.params[ParameterIdents[i]] = param;
    }

    enum annotations = getUDAs!(Member, Doc);
    static if (annotations.length)
    {
        enum content = annotations[0].content;
        parseDocumentationContent(ret, content);
    }
    else
        ret.note = "no doc";

    return ret;
}


/**
 * Генерация документации на используемые в методе типы
 * Params:
 * IType  = Тип интерфейса контроллера
 * Member = Символ метода
 */
ModelDoc[] generateTypesDocumentation(IType, alias Member)()
{
    alias ParameterTypes = ParameterTypeTuple!Member;
    alias RT = ReturnType!Member;

    ModelDoc[] ret;

    foreach (i, T; ParameterTypes)
        generateFieldDocumentation!T(ret);

    generateFieldDocumentation!(RT)(ret);

    return ret;
}


private:


void generateFieldDocumentation(Field)(ref ModelDoc[] ret)
{
    foreach(IField; getInternalTypes!Field)
    {
        enum modelName = IField.stringof;
        if (ret.canFind!((t) => t.name == modelName))
            break;

        static if (isCompositeType!IField)
        {
            alias MemberNameTuple = FieldNameTuple!IField;

            ModelDoc td;
            td.name = modelName;

            foreach(i, MemberType; Fields!IField)
            {
                enum name = MemberNameTuple[i];
                static if (IsPublicMember!(IField, name))
                {
                    FieldDoc fd;
                    fd.typeDoc = getFieldModelDoc!MemberType;

                    enum annotations = getUDAs!(__traits(getMember, IField, name), Doc);
                    static if (annotations.length)
                        fd.note = annotations[0].content;

                    static if (isCompositeType!MemberType)
                        fd.typeLink = getFieldModelDocLink!MemberType;

                    td.members[name] = fd;
                }
            }

            ret ~= td;

            foreach(i, MemberType; Fields!IField)
            {
                enum name = MemberNameTuple[i];
                static if (IsPublicMember!(IField, name))
                    generateFieldDocumentation!(MemberType)(ret);
            }
        }
    }
}


template getInternalTypes(T)
{
    static if (isArray!T)
        alias getInternalTypes = AliasSeq!(Unqual!(ForeachType!T));
    else static if (isAssociativeArray!T)
        alias getInternalTypes = AliasSeq!(
                Unqual!(ForeachType!T),
                Unqual!(KeyType!T));
    else static if (isInstanceOf!(Nullable, T))
        alias getInternalTypes = TemplateArgsOf!T;
    else
        alias getInternalTypes = AliasSeq!(Unqual!T);
}


template isCompositeType(T)
{
    enum isCompositeType = isAggregateType!T
        && !is(T == UniNode);
}


template getFieldModelDoc(T)
{
    enum getFieldModelDoc = T.stringof;
}


template getFieldModelDocLink(T)
{
    enum getFieldModelDocLink = "#" ~ T.stringof;
}

