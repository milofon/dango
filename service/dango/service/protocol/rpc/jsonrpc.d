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
        response["jsonrpc"] = UniNode("2.0");
        response["id"] = *id;
        response["result"] = result;
        return UniNode(response);
    }
}


alias JsonRpcServerProtocolFactory = RpcServerProtocolFactory!(
                JsonRpcServerProtocol, "JSONRPC");



class JsonRpcClientProtocol : BaseRpcClientProtocol
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
        request["params"] = params;
        return UniNode(request);
    }


    override UniNode parseResponse(UniNode response)
    {
        if (response.type != UniNode.Type.object)
            throw new RpcException(ErrorCode.INTERNAL_ERROR, "Error response");

        auto responseMap = response.via.map;
        if (auto error = "error" in responseMap)
        {
            int errorCode;
            string errorMsg;
            auto errorMap = (*error).via.map;

            if (auto codePtr = "code" in errorMap)
                errorCode = (*codePtr).get!int;

            if (auto msgPtr = "message" in errorMap)
                errorMsg = (*msgPtr).get!string;

            if (auto dataPtr = "data" in errorMap)
                throw new RpcException(errorCode, errorMsg, *dataPtr);
            else
                throw new RpcException(errorCode, errorMsg);
        }
        else if (auto result = "result" in responseMap)
            return *result;

        throw new RpcException(ErrorCode.INTERNAL_ERROR,
                "The response does not match the format");
    }
}



alias JsonRpcClientProtocolFactory = RpcClientProtocolFactory!(
                JsonRpcClientProtocol, "JSONRPC");

