/**
 * Модуль протокала RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-12-05
 */

module dango.service.protocol.rpc;

public
{
    import dango.service.protocol.rpc.controller : Method, Controller,
            GenericRpcController, registerController;

    import dango.service.protocol.rpc.error : enforceRpc, enforceRpcData;
    import dango.service.protocol.rpc.schema;
}

