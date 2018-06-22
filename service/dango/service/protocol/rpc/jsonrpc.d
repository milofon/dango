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

    import dango.service.protocol.rpc.plain;
}


/**
 * Протокол JsonRPC
 */
class JsonRpcServerProtocol : PlainRpcServerProtocol
{
    override UniNode createErrorHeader(D...)(int code, string msg, D data)
    {
        UniNode[string] response;
        response["jsonrpc"] = UniNode("2.0");
        response["id"] = UniNode();
        UniNode[string] err;

        static if (data.length == 1)
        {
            static if (is(D[0] == UniNode))
                err["data"] = data[0];
            else
                err["data"] = marshalObject(data[0]);
        }
        else static if (data.length > 1)
        {
            UniNode[] edata;
            foreach (dt; data)
                edata ~= marshalObject(dt);
            err["data"] = UniNode(edata);
        }

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

