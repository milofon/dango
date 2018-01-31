/**
 * Реализация упрощенного RPC протокола
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.simple;

private
{
    import dango.service.protocol.core;
}



class SimpleRpcProtocol : RpcProtocol
{
    void initialize(Dispatcher dispatcher, Serializer serializer, Properties config)
    {

    }


    ubyte[] handle(ubyte[] data)
    {
        return data;
    }
}
