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

    import dango.service.protocol.rpc.doc.parser : parseDocumentation;
}


/**
 * Аннотация определяет документацию для обработчика команды
 */
struct Doc
{
    string content;
}



struct MethodDoc
{
    string method;
    string content;
    string[] params;
}


/**
 * Функция регистрации обработчика запроса
 */
alias RegisterDoc = void delegate(MethodDoc);


/**
 * Генерация документации на основе аннотации метода
 * Params:
 * IType  = Тип интерфейса контроллера
 * name   = Имя метода
 * Member = Символ метода
 */
MethodDoc generateDocumentation(IType, string name, alias Member)()
{
    enum annotations = getUDAs!(Member, Doc);
    static if (annotations.length)
    {
        enum content = annotations[0].content;
        return parseDocumentation(name, content);
    }
    else
        return MethodDoc(name ~ "no doc");
}

