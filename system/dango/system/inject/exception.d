/**
 * Модуль исключений модуля контейнер
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-11-20
 */

module dango.system.inject.exception;

private
{
    import dango.system.exception : ExceptionMixin;
}


/**
 * Ошибка в пакете container
 */
class DangoContainerException : Exception
{
    mixin ExceptionMixin!();
}


/**
 * Ошибка в модуле компонент
 */
class DangoComponentException : Exception
{
    mixin ExceptionMixin!();
}

