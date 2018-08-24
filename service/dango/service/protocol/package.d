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
    import dango.system.container;

    import dango.service.protocol.graphql;

    import dango.service.protocol.rpc.plain;
    import dango.service.protocol.rpc.jsonrpc;

    import dango.service.protocol.rpc.schema.web;
}


/**
 * Контекст DI протоколов
 */
class ProtocolContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerNamedFactory!(GraphQLServerProtocolFactory,
                GraphQLServerProtocol, "GRAPHQL");

        container.registerNamedFactory!(PlainRpcServerProtocolFactory,
                PlainRpcServerProtocol, "PLAIN");
        container.registerNamedFactory!(JsonRpcServerProtocolFactory,
                JsonRpcServerProtocol, "JSONRPC");

        container.registerNamedFactory!(RpcDocumentationWebControllerFactory,
                RpcDocumentationWebController, "RPCDOC");

        container.registerNamedFactory!(PlainRpcClientProtocolFactory,
                PlainRpcClientProtocol, "PLAIN");
        container.registerNamedFactory!(JsonRpcClientProtocolFactory,
                JsonRpcClientProtocol, "JSONRPC");
    }
}

