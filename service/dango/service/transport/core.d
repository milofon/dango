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
    import proped : Properties;

    import dango.service.protocol: RpcProtocol;
}


interface Transport
{
    /**
     * Запуск транспортного уровня
     * Params:
     * config = Конфигурация транспорта
     */
    void listen(RpcProtocol protocol, Properties config);


    /**
     * Завершение работы
     */
    void shutdown();
}
