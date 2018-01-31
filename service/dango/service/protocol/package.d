/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol;

public
{
    import dango.service.protocol.core : RpcProtocol, RPCException,
           createEmptyErrorByCode, createErrorByCode, ErrorCode, RPCError;
}

private
{
    import poodinis : DependencyContainer, ApplicationContext,
           newInstance;
    import dango.system.container : registerByName;

    import dango.service.protocol.jsonrpc : JsonRPCProtocol;
    import dango.service.protocol.simple : SimpleRpcProtocol;
}


class ProtocolContext : ApplicationContext
{
    override void registerDependencies(shared(DependencyContainer) container)
    {
        container.registerByName!(RpcProtocol, JsonRPCProtocol)("jsonrpc").newInstance;
        container.registerByName!(RpcProtocol, SimpleRpcProtocol)("simple").newInstance;
    }
}
