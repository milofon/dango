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
    import dango.service.types : Bytes;
}

private
{
    import uniconf.core : Config;
    import dango.system.inject;
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
 * Фабрика серверного транспортного уровня
 */
alias ServerTransportFactory = ComponentFactory!(ServerTransport, Config,
        ApplicationContainer);


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
 * Фабрика клиентского транспортного уровня
 */
alias ClientTransportFactory = ComponentFactory!(ClientTransport, Config);

