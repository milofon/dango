/**
 * Модуль содержит слассы ошибок и вспомогательные фунции
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.exception;

public
{
    import dango.system.exception;
}


private
{
    import std.exception : enforce;

    import dango.system.exception : ExceptionMixin;
}


/**
 * Исключение транспорта
 */
class TransportException : Exception
{
    mixin ExceptionMixin!();
}


alias transportEnforce = enforce!(TransportException);

