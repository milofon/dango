/**
 * Модуль содержит методы для генерации кода
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-02-11
 */

module dango.system.traits;

private
{
    import std.traits;
    import std.meta;
    import std.typecons;
}


/**
 * Проверка на публичность методов
 * Params:
 * C = Объект
 * N = Наименование метода
 */
template IsPublicMember(C, string N)
{
    static if (__traits(compiles, __traits(getMember, C, N)))
    {
        alias member = Alias!(__traits(getMember, C, N));
        static if (__traits(compiles, __traits(getProtection, member)))
        {
            enum access = __traits(getProtection, member);
            enum IsPublicMember = access == "public";
        }
        else
            enum IsPublicMember = false;
    }
    else
        enum IsPublicMember = false;
}


/**
 * В случае необходимости преобразует unsafe функцию в safe
 *
 * Params:
 * fun = Указатель на функцию или делегат
 */
auto assumeSafe(F)(F fun) @safe
    if (isFunctionPointer!F || isDelegate!F)
{
    static if (hasFunctionAttributes!(F, "@safe"))
        return fun;
    else
        return (ParameterTypeTuple!F args) @trusted {
            return fun(args);
        };
}



/+
/**
 * Обработка мемберов указанного типа.
 * На каждый публичный мембер вызывается делегат
 * Params:
 * T      = Тип
 * DG     = Делегат
 * object = Экземпляр типа T
 */
void eachPublicMembers(T, alias DG, A...)(T object, A args)
{
    foreach (string fName; __traits(allMembers, T))
    {
        static if(IsPublicMember!(T, fName))
        {
            alias Member = Alias!(__traits(getMember, T, fName));
            DG!(T, Member)(object, args);
        }
    }
}



template Pair(string N, T)
{
    alias NAME = N;
    alias TYPE = T;
}



template byPair(NList...)
{
    static if (NList.length > 1)
        alias byPair = AliasSeq!(
                Pair!(NList[0], NList[1]),
                byPair!(NList[2..$]));
    else
        alias byPair = AliasSeq!();
}
+/

