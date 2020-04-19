/**
 * Модуль содержит слассы ошибок и вспомогательные фунции
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-03-27
 */

module dango.system.exception;

private
{
    import std.exception : basicExceptionCtors;
}


/**
 * Base application exception
 */
class DangoApplicationException : Exception
{
    mixin basicExceptionCtors;
}

