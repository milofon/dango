/**
 * Общий модуль для протоколов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.core;

public
{
    import proped : Properties;

    import vibe.http.server : HTTPServerRequest, HTTPServerResponse,
           HTTPServerRequestHandler;

    import dango.system.container : ApplicationContainer;

    import dango.service.global;
    import dango.service.serialization : Serializer;
}


/**
 * Интерфейс серверного протокола взаимодействия
 */
interface ServerProtocol : Configurable!(Serializer, ApplicationContainer, Properties) {}


/**
 * Интерфейс бинарного серверного протокола взаимодействия
 */
interface BinServerProtocol : ServerProtocol
{
    /**
     * Метод-обработик входящейго запроса
     * Params:
     * data = Бинарные данные
     * Return: Ответ в бинарном виде
     */
    Bytes handle(Bytes data);
}


/**
 * Интерфейс http серверного протокола взаимодействия
 */
interface HTTPServerProtocol : ServerProtocol, HTTPServerRequestHandler {}


/**
 * Базовый класс серверного протокола взаимодействия
 */
abstract class BaseServerProtocol(T : ServerProtocol) : T
{
    protected
    {
        Serializer serializer;
    }


    final void configure(Serializer serializer, ApplicationContainer container,
            Properties config)
    {
        this.serializer = serializer;
        protoConfigure(container, config);
    }


    void protoConfigure(ApplicationContainer container, Properties config);
}

