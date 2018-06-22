/**
 * Модуль глобальных типов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-01
 */

module dango.service.global;


/**
 * Массив иммутабельных байт
 */
alias Bytes = immutable(ubyte)[];


/**
 * Компонент системы, который ассоциирован с именем
 */
interface Named
{
    /**
     * Возвращает имя компонента
     */
    string name() @property;
}


/**
 * Компонент системы, который требует конфигурирования
 */
interface Configurable(A...)
{
    /**
     * Конфигурация компонента
     * Params:
     * args = Кортеж аргументов
     */
    void configure(A args);
}


/**
 * Компонент системы, который содержит состояние активности
 */
interface Activated
{
    /**
     * Возвращает активность компонента
     */
    bool enabled() @property;
}

