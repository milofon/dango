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
    import dango.system.container : ApplicationContainer;

    import dango.service.types;
    import dango.service.serialization : Serializer;
}

private
{
    import dango.system.component;
}


/**
 * Интерфейс серверного протокола взаимодействия
 */
interface ServerProtocol : Named
{
    /**
     * Метод-обработик входящейго запроса
     * Params:
     * data = Бинарные данные
     * Return: Ответ в бинарном виде
     */
    Bytes handle(Bytes data);
}



abstract class BaseServerProtocol(string N) : ServerProtocol
{
    mixin NamedMixin!N;


    protected Serializer serializer;

    this(Serializer serializer)
    {
        this.serializer = serializer;
    }
}



alias BaseServerProtocolFactory(T : ServerProtocol) = AutowireComponentFactory!(
        ServerProtocol, T, Serializer);

