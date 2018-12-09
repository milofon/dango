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
class JsonRpcServerProtocol : BaseRpcServerProtocol!"JSONRPC"
{
    this(Serializer serializer)
    {
        super(serializer);
    }


    override UniNode createErrorHeader(UniNode* id, int code, string msg, UniNode data)
    {
        UniNode[string] response;
        response["jsonrpc"] = UniNode("2.0");
        response["id"] = (id is null) ? UniNode() : *id;
        UniNode[string] err;

        if (data.kind != UniNode.Kind.nil)
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



alias JsonRpcServerProtocolFactory = RpcServerProtocolFactory!(JsonRpcServerProtocol);


/**
 * Клиентский протокол JSON
 */
class JsonRpcClientProtocol : BaseRpcClientProtocol!"JSONRPC"
{
    private ulong counterId;


    this(ClientTransport transport, Serializer serializer)
    {
        super(transport, serializer);
    }


    override UniNode createRequest(string cmd, UniNode params)
    {
        UniNode[string] request;
        request["jsonrpc"] = UniNode("2.0");
        request["id"] = UniNode(++counterId);
        request["method"] = UniNode(cmd);
        if (params.kind != UniNode.Kind.nil)
            request["params"] = params;
        return UniNode(request);
    }


    override UniNode parseResponse(UniNode response)
    {
        if (response.kind != UniNode.Kind.object)
            throw new RpcException(ErrorCode.INTERNAL_ERROR, "Error response");

        if (auto error = "error" in response)
        {
            int errorCode;
            string errorMsg;

            if (auto codePtr = "code" in *error)
                errorCode = (*codePtr).get!int;

            if (auto msgPtr = "message" in *error)
                errorMsg = (*msgPtr).get!string;

            if (auto dataPtr = "data" in *error)
                throw new RpcException(errorCode, errorMsg, *dataPtr);
            else
                throw new RpcException(errorCode, errorMsg);
        }
        else if (auto result = "result" in response)
            return *result;

        throw new RpcException(ErrorCode.INTERNAL_ERROR,
                "The response does not match the format");
    }
}



alias JsonRpcClientProtocolFactory = RpcClientProtocolFactory!(JsonRpcClientProtocol);

