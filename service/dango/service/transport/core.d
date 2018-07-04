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
    import dango.system.container : ApplicationContainer;
    import dango.service.protocol : ServerProtocol;
}

private
{
    import dango.system.component;

    import dango.service.types;
}


/**
 * Интерфейс серверного транспортного уровня
 */
interface ServerTransport : Named
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
    mixin NamedMixin!N;
}


/**
 * Базовый класс фабрики серверного транспортного уровня
 */
alias BaseServerTransportFactory(T : ServerTransport) = AutowireComponentFactory!(
        ServerTransport, T, ServerProtocol);

