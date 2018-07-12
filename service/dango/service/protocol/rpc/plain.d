/**
 * Реализация упрощенного Rpc протокола
*
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.rpc.plain;

private
{
    import dango.service.serialization;
    import dango.service.protocol.rpc.core;
}



class PlainRpcServerProtocol : BaseRpcServerProtocol
{
    this(Serializer serializer)
    {
        super(serializer);
    }


    override UniNode createErrorHeader(UniNode* id, int code, string msg, UniNode data)
    {
        UniNode[string] response;
        response["id"] = (id is null) ? UniNode() : *id;
        UniNode[string] err;

        if (data.type != UniNode.Type.nil)
            err["data"] = data;
        err["code"] = UniNode(code);
        err["message"] = UniNode(msg);

        response["error"] = UniNode(err);
        return UniNode(response);
    }


    override UniNode createResultBody(UniNode* id, UniNode result)
    {
        if (id is null)
            return UniNode();

        UniNode[string] response;
        response["id"] = *id;
        response["result"] = result;
        return UniNode(response);
    }
}



alias PlainRpcServerProtocolFactory = RpcServerProtocolFactory!(
                PlainRpcServerProtocol, "PLAIN");

