/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-12
 */

module dango.service.protocol.rpc.doc;

private
{
    import std.traits;
    import std.meta;
    import std.conv : to;
    import std.array : appender, Appender;

    import vibe.data.serialization : optional;

    import dango.service.serialization : UniNode, marshalObject;
    import dango.service.protocol.rpc.doc.parser : parseDocumentation;
}


/**
 * Обработчик метода получения документации
 */
class DocumataionHandler
{
    private Appender!(MethodDoc[]) _methods;


    string method() @property
    {
        return "__doc";
    }


    UniNode handle(UniNode params)
    {
        return marshalObject(_methods.data);
    }


    void registerMethodDoc(MethodDoc md)
    {
        _methods.put(md);
    }


    void registerTypeDoc(TypeDoc[] td)
    {
        import std.stdio: wl = writeln;
    }
}


/**
 * Аннотация определяет документацию для обработчика команды
 */
struct Doc
{
    string content;
}


/**
  * Документация метода
  */
struct MethodDoc
{
    string method;
    string content;

    string retTypeDoc;
    string retDoc;

    FieldDoc[] params;
}



struct FieldDoc
{
    string name; // имя поля
    string note; // примечание
    string typeDoc; // наименование типа
    UniNode defVal; // значение по умолчанию
}



struct TypeDoc
{
    string name; // имя типа
}


alias RegisterMethodDoc = void delegate(MethodDoc);

alias RegisterTypeDoc = void delegate(TypeDoc[]);


/**
 * Генерация документации на основе аннотации метода
 * Params:
 * IType  = Тип интерфейса контроллера
 * name   = Имя метода
 * Member = Символ метода
 */
MethodDoc generateMethodDocumentation(IType, string name, alias Member)()
{
    enum annotations = getUDAs!(Member, Doc);
    static if (annotations.length)
    {
        enum content = annotations[0].content;
        alias ParameterIdents = ParameterIdentifierTuple!Member;
        alias ParameterTypes = ParameterTypeTuple!Member;
        alias ParameterDefs = ParameterDefaults!Member;
        alias RT = ReturnType!Member;

        MethodDoc ret;
        ret.retTypeDoc = generateTypeDoc!RT;

        foreach (i, T; ParameterTypes)
        {
            FieldDoc param;
            param.name = ParameterIdents[i];
            param.typeDoc = generateTypeDoc!T;

            alias def = ParameterDefs[i];
            static if (!is(def == void))
                param.defVal = UniNode(def);

            ret.params ~= param;
        }

        parseDocumentation(ret, name, content);
        return ret;
    }
    else
        return MethodDoc(name ~ "no doc");
}


/**
 * Генерация документации на используемые в методе типы
 * Params:
 * IType  = Тип интерфейса контроллера
 * Member = Символ метода
 */
TypeDoc[] generateTypesDocumentation(IType, alias Member)()
{
    alias ParameterTypes = ParameterTypeTuple!Member;
    TypeDoc[] ret;
    return ret;
}


private:


template generateTypeDoc(T)
{
    enum generateTypeDoc = T.stringof;
}

