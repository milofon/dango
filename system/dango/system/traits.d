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
}


/**
 * Проверка на публичность методов
 * Params:
 * C = Объект
 * N = Наименование метода
 */
template IsPublicMember(C, string N)
{
    enum access = __traits(getProtection, __traits(getMember, C, N));
    enum IsPublicMember = access == "public";
}
