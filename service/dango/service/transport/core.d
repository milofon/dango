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

    import dango.system.container : ApplicationContainer;
    import dango.service.protocol: ServerProtocol;
}

private
{
    import dango.service.global;
}


/**
 * Интерфейс серверного транспортного уровня
 */
interface ServerTransport : Configurable!(ApplicationContainer,
        ServerProtocol, Properties), Named
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
 * Базовый класс серверного транспортного уровня
 */
abstract class BaseServerTransport(string N) : ServerTransport
{
    enum NAME = N;

    protected
    {
        ServerProtocol protocol;
    }


    void configure(ApplicationContainer container,
            ServerProtocol protocol, Properties config)
    {
        this.protocol = protocol;
        transportConfigure(container, config);
    }


    void transportConfigure(ApplicationContainer container, Properties config);


    string name() @property
    {
        return NAME;
    }
}

