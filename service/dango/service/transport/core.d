/**
 * Основной модуль транспортного уровня
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport.core;


public
{
    import vibe.core.concurrency : Future;

    import dango.system.container : ApplicationContainer;
    import dango.service.protocol : ServerProtocol;
}

private
{
    import dango.system.container;
    import dango.service.types;
}


/**
 * Интерфейс серверного транспортного уровня
 */
interface ServerTransport
{
    /**
     * Запуск транспортного уровня
     * Params:
     * proto = Протокол взаимодейтсвия
     */
    void listen();

    /**
     * Завершение работы
     */
    void shutdown();
}


/**
 * Базовый класс фабрики серверного транспортного уровня
 */
abstract class BaseServerTransportFactory(string N) : ComponentFactory!(
        ServerTransport, ApplicationContainer, ServerProtocol), Named
{
    mixin NamedMixin!N;
}


/**
 * Интерфейс клиентского транспортного уровня
 */
interface ClientTransport
{
    /**
     * Выполнение запроса
     * Params:
     * bytes = Входящие данные
     * Return: Данные ответа
     */
    Future!Bytes request(Bytes bytes);
}


/**
 * Базовый класс фабрики клиентского транспортного уровня
 */
abstract class BaseClientTransportFactory(string N) :
    ComponentFactory!(ClientTransport), Named
{
    mixin NamedMixin!N;
}

