/**
 * Реализация Rpc протокола JsonRpc 2.0
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.rpc.jsonrpc;

private
{
    import dango.service.serialization;
    import dango.service.protocol.rpc.core;
}


/**
 * Протокол JsonRPC
 */
class JsonRpcServerProtocol : BaseRpcServerProtocol
{
    this(Serializer serializer)
    {
        super(serializer);
    }


    override UniNode createErrorHeader(UniNode* id, int code, string msg, UniNode data)
    {
        UniNode[string] response;
        response["jsonrpc"] = UniNode("2.0");
        response["id"] = UniNode();
        UniNode[string] err;

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
        response["jsonrpc"] = UniNode("2.0");
        response["id"] = *id;
        response["result"] = result;
        return UniNode(response);
    }
}


alias JsonRpcServerProtocolFactory = RpcServerProtocolFactory!(
                JsonRpcServerProtocol, "JSONRPC");

