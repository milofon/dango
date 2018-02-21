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
    import std.container : SList;

    import proped : Properties;

    import vibe.core.core : Mutex, yield;
    import vibe.core.sync;

    import dango.service.protocol: RpcServerProtocol;
}


/**
 * Интерфейс серверного транспортного уровня
 */
interface ServerTransport
{
    /**
     * Запуск транспортного уровня
     * Params:
     * config = Конфигурация транспорта
     */
    void listen(RpcServerProtocol protocol, Properties config);

    /**
     * Завершение работы
     */
    void shutdown();
}


/**
 * Интерфейс клиентского транспортного уровня
 */
interface ClientTransport
{
    /**
     * Инициализация транспорта клиента
     */
    void initialize(Properties config);


    /**
     * Выполнение запроса
     * Params:
     * bytes = Входящие данные
     * Return: Данные ответа
     */
    ubyte[] request(ubyte[] bytes);
}


/**
  * Интерфейс подключения с возможностью хранения в пуле
  */
interface ClientConnection
{
    /**
     * Проверка на активность подключения
     */
    bool connected() @property;

    /**
     * Установка подключения
     */
    void connect();

    /**
     * Разрыв соединения
     */
    void disconnect();
}


/**
 * Интерфейс пула подключений
 */
interface ClientConnectionPool(C)
{
    /**
     * Получить подключение из пула
     */
    C getConnection() @safe;

    /**
     * Вернуть подключение в пул
     * Params:
     *
     * conn = Освобождаемое подключение
     */
    void freeConnection(C conn) @safe;

    /**
     * Создание нового подключения
     */
    C createNewConnection();
}


/**
 * Класс пула с возможностью работы с конкурентной многозадачностью
 */
abstract class AsyncClientConnectionPool(C) : ClientConnectionPool!C
{
    private
    {
        SList!C _pool;
        Mutex _mutex;
        uint _size;
    }


    this(uint size)
    {
        _mutex = new Mutex();
        _size = size;
        initializePool();
    }


    C getConnection() @safe
    {
        _mutex.lock();
        while (_pool.empty)
            yield();

        auto conn = () @trusted {
            auto conn = _pool.front();
            if (!conn.connected)
                conn.connect();
            return conn;
        } ();

        _pool.removeFront();
        _mutex.unlock();
        return conn;
    }


    void freeConnection(C conn) @safe
    {
        _mutex.lock();
        _pool.insertFront(conn);
        _mutex.unlock();
    }


    private void initializePool()
    {
        _mutex.lock();
        foreach (i; 0.._size)
            _pool.insertFront(createNewConnection());
        _mutex.unlock();
    }
}


/**
 * Класс пула с возможностью работы с многозадачностью на основе потоков
 */
abstract class WaitClientConnectionPool(C) : ClientConnectionPool!C
{

}
