/**
 * Реализация Rpc протокола JsonRpc 2.0
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.jsonrpc;

private
{
    import std.string : strip;

    import vibe.core.log;

    import dango.service.protocol.core;
    import dango.service.serializer.core;
    import dango.service.transport.core;
}



class JsonRpcServerProtocol : RpcServerProtocol
{
    private
    {
        Dispatcher _dispatcher;
        Serializer _serializer;
    }


    void initialize(Dispatcher dispatcher, Serializer serializer, Properties config)
    {
        _dispatcher = dispatcher;
        _serializer = serializer;
    }


    ubyte[] handle(ubyte[] data)
    {
        UniNode uniReq;
        try
            uniReq = _serializer.deserialize(data);
        catch (Exception e)
        {
            logInfo("Error deserialize: (%s)", e.msg);
            return createErrorBody(createErrorByCode(
                    ErrorCode.PARSE_ERROR, e.msg));
        }

        string method;
        UniNode* id;
        UniNode params;

        try
        {
            auto vMethod = "method" in uniReq;
            if (!vMethod || !(vMethod.type == UniNode.Type.text
                        || vMethod.type == UniNode.Type.raw))
            {
                logInfo("Not found method");
                return createErrorBody(createErrorByCode!string(
                        ErrorCode.INVALID_REQUEST,
                        "Parameter method is invalid"));
            }

            method = (*vMethod).get!string.strip;
            id = "id" in uniReq;
            params = UniNode.emptyObject();
            if (auto pv = "params" in uniReq)
                params = *pv;
        }
        catch (Exception e)
        {
            logInfo("Error extract meta info: (%s)", e.msg);
            return createErrorBody(createErrorByCode(
                    ErrorCode.SERVER_ERROR, e.msg));
        }

        if (_dispatcher.existst(method))
        {
            try
            {
                UniNode uniRes = _dispatcher.handler(method, params);
                return createResultBody(id, uniRes);
            }
            catch (RpcException e)
                return createErrorBody(e.error);
            catch (Exception e)
            {
                logInfo("Error execute handler: (%s)", e.msg);
                return createErrorBody(createErrorByCode(
                        ErrorCode.SERVER_ERROR, e.msg));
            }
        }
        else
            return createErrorBody(createEmptyErrorByCode(
                ErrorCode.METHOD_NOT_FOUND));
    }

private:

    ubyte[] createErrorBody(T)(RpcError!T error)
    {
        RpcError!UniNode uniError;
        uniError.code = error.code;
        uniError.message = error.message;
        if (!error.data.isNull)
            uniError.data = marshalObject!T(error.data);
        return createErrorBody(uniError);
    }


    ubyte[] createErrorBody(RpcError!UniNode error)
    {
        UniNode[string] response;
        response["jsonrpc"] = UniNode("2.0");
        response["id"] = UniNode();
        UniNode[string] err;
        err["code"] = UniNode(error.code);
        err["message"] = UniNode(error.message);
        if (!error.data.isNull)
            err["data"] = error.data.get;
        response["error"] = UniNode(err);
        return _serializer.serialize(UniNode(response));
    }


    ubyte[] createResultBody(UniNode* id, UniNode result)
    {
        if (id is null)
            return [];

        UniNode[string] response;
        response["jsonrpc"] = UniNode("2.0");
        response["id"] = *id;
        response["result"] = result;
        return _serializer.serialize(UniNode(response));
    }
}



class JsonRpcClientProtocol : RpcClientProtocol
{
    private
    {
        Serializer _serializer;
        ClientTransport _transport;
    }

    this(Serializer serializer, ClientTransport transport)
    {
        _serializer = serializer;
        _transport = transport;
    }


    UniNode request(string cmd, UniNode params)
    {
        UniNode[string] request;
        request["jsonrpc"] = UniNode("2.0");
        request["id"] = UniNode(2.0);
        request["method"] = UniNode(cmd);
        request["params"] = params;

        ubyte[] resData;
        try
        {
            auto reqData = _serializer.serialize(UniNode(request));
            resData = _transport.request(reqData);
        }
        catch (Exception e)
            throw new RpcException(ErrorCode.SERVER_ERROR, e.msg);

        if (resData.length <= 0)
            throw new RpcException(ErrorCode.INTERNAL_ERROR, "Empty response");

        auto response = _serializer.deserialize(resData);
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

        throw new RpcException(ErrorCode.INTERNAL_ERROR, "Not found result");
    }
}
