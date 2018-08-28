/**
 * Модуль подключения к базе данных
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-08-28
 */

module dango.store.pool;

private
{
    import std.container : SList;

    import vibe.core.sync;
}


/**
  * Интерфейс объекта с возможностью хранения в пуле
  */
interface Connection
{
    bool connected() @property;

    void connect();

    void disconnect();
}


/**
  * Интерфейс пула
  */
interface ConnectionPool(C)
{
    /**
     * Получить подключение из пула
     */
    C connection() @safe;

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



abstract class BaseConnectionPool(C) : ConnectionPool!C
{
    private
    {
        SList!C _pool;
        Mutex _mutex;
        TaskCondition _condition;
        uint _size;
    }


    this(uint size)
    {
        _mutex = new Mutex();
        _condition = new TaskCondition(_mutex);
        _size = size;
        initializePool();
    }


    /**
     * Получить подключение из пула
     */
    C connection() @safe
    {
        _mutex.lock();
        while (_pool.empty)
            _condition.wait();

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

    /**
     * Вернуть подключение в пул
     * Params:
     *
     * conn = Освобождаемое подключение
     */
    void freeConnection(C conn) @safe
    {
        _mutex.lock();
        _pool.insertFront(conn);
        _condition.notify();
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

