/**
 * Модуль содержит слассы ошибок и вспомогательные фунции
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-15
 */

module dango.inject.exception;

private
{
    import std.exception : basicExceptionCtors;
    import std.format : fmt = format;
}


/**
 * Base application exception
 */
class InjectDangoException : Exception
{
    mixin basicExceptionCtors;
}


/**
 * Exception thrown when errors occur while resolving a type in a dependency container.
 */
class ResolveDangoException : Exception 
{
    this(string message, TypeInfo resolveType) @safe
    {
        super(fmt!"Exception while resolving type %s: %s"(
                resolveType.toString(), message));
    }

    this(Throwable cause, TypeInfo resolveType) @safe
    {
        super(fmt!"Exception while resolving type %s"(
                    resolveType.toString()), cause);
    }
}


/**
 * Exception thrown when errors occur while registering a type in a dependency container.
 */
class RegistrationDangoException : Exception 
{
    this(string message, TypeInfo registrationType) @safe
    {
        super(fmt!("Exception while registering type %s: %s")(
                    registrationType.toString(), message));
    }
}

