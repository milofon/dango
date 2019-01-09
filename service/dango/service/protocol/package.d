/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol;

public
{
    import dango.service.protocol.core : ServerProtocol;
}

private
{
    import dango.system.inject;

    import dango.service.protocol.rpc.plain;
    import dango.service.protocol.rpc.jsonrpc;

    import dango.web.controller : registerController;
    import dango.service.protocol.rpc.schema.web;
}


/**
 * Контекст DI протоколов
 */
class ProtocolContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerNamedFactory!(PlainRpcServerProtocol, PlainRpcServerProtocol.NAME,
                PlainRpcServerProtocolFactory);
        container.registerNamedFactory!(JsonRpcServerProtocol, JsonRpcServerProtocol.NAME,
                JsonRpcServerProtocolFactory);

        container.registerController!(RpcDocumentationWebController,
                RpcDocumentationWebControllerFactory, "RPCDOC");

        container.registerNamedFactory!(PlainRpcClientProtocol, PlainRpcClientProtocol.NAME,
                PlainRpcClientProtocolFactory);
        container.registerNamedFactory!(JsonRpcClientProtocol, JsonRpcServerProtocol.NAME,
                JsonRpcClientProtocolFactory);
    }
}

