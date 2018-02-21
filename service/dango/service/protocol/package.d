/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol;

public
{
    import dango.service.protocol.core : RpcServerProtocol, RpcClientProtocol,
           RpcException, createEmptyErrorByCode, createErrorByCode, ErrorCode, RpcError;
}

private
{
    import poodinis : DependencyContainer, ApplicationContext,
           newInstance;
    import dango.system.container : registerByName;

    import dango.service.protocol.jsonrpc : JsonRpcServerProtocol, JsonRpcClientProtocol;
    import dango.service.protocol.simple : SimpleRpcServerProtocol, SimpleRpcClientProtocol;
}


class ProtocolContext : ApplicationContext
{
    override void registerDependencies(shared(DependencyContainer) container)
    {
        container.registerByName!(RpcServerProtocol, JsonRpcServerProtocol)("jsonrpc").newInstance;
        container.registerByName!(RpcServerProtocol, SimpleRpcServerProtocol)("simple").newInstance;

        container.registerByName!(RpcClientProtocol, JsonRpcClientProtocol)("jsonrpc").newInstance;
        container.registerByName!(RpcClientProtocol, SimpleRpcClientProtocol)("simple").newInstance;
    }
}
