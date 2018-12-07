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
    import dango.system.container : ApplicationContainer;

    import dango.service.types : Bytes;
    import dango.service.serialization : Serializer;
}

private
{
    import std.typecons : Tuple;
    import uniconf.core : Config;
    import dango.system.container;
}


/**
 * Интерфейс серверного протокола взаимодействия
 */
interface ServerProtocol : NamedComponent
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


/**
 * Базовый класс серверного протокола взаимодействия
 */
abstract class BaseServerProtocol(string N) : ServerProtocol
{
    mixin NamedComponentMixin!N;
    protected Serializer _serializer;


    this(Serializer serializer)
    {
        this._serializer = serializer;
    }


    Serializer serializer() @property
    {
        return _serializer;
    }
}



alias ServerProtocolFactory = ComponentFactory!(ServerProtocol, Config,
        ApplicationContainer);


/**
 * Контейнер для фабрик протоколов
 */
class ServerProtocolContainer
{
    alias Factory = ComponentFactoryWrapper!ServerProtocol;
    alias PreInitPactory = Tuple!(Factory, Config, ApplicationContainer);
    private PreInitPactory[string] _data;

    /**
     * Регистрация фабрики протокола
     */
    void registerProtocolFactory(string key, Factory factory, Config config,
            ApplicationContainer container)
    {
        _data[key] = PreInitPactory(factory, config, container);
    }

    /**
     * Создает новый протокол
     */
    ServerProtocol createProtocol(string key)
    {
        if (auto fPtr = key in _data)
        {
            auto pf = *fPtr;
            return pf[0].createInstance(pf[1], pf[2]);
        }
        return null;
    }
}

