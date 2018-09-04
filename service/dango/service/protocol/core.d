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
    import uniconf.core : Config;
    import dango.system.container : ApplicationContainer;

    import dango.service.types;
    import dango.service.serialization : Serializer;
}

private
{
    import dango.system.container;
}


/**
 * Интерфейс серверного протокола взаимодействия
 */
interface ServerProtocol
{
    /**
     * Метод-обработик входящейго запроса
     * Params:
     * data = Бинарные данные
     * Return: Ответ в бинарном виде
     */
    Bytes handle(Bytes data);

    /**
     * Возвращает сериализатор
     */
    Serializer serializer() @property;
}



abstract class BaseServerProtocol : ServerProtocol
{
    private Serializer _serializer;


    this(Serializer serializer)
    {
        this._serializer = serializer;
    }


    Serializer serializer() @property
    {
        return _serializer;
    }
}



alias BaseServerProtocolFactory = ComponentFactory!(ServerProtocol, Config,
        ApplicationContainer, Serializer);

