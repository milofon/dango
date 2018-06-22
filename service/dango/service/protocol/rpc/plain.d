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
    import std.string : strip;
    import std.format : fmt = format;

    import vibe.core.log;

    import dango.system.properties : getNameOrEnforce, configEnforce;
    import dango.system.container : resolveNamed;

    import dango.service.serialization;
    import dango.service.protocol.core;
    import dango.service.protocol.rpc.error;
    import dango.service.protocol.rpc.controller;
    import dango.service.protocol.rpc.client;
}


/**
 * Серверный протокол Simple
 */
class PlainRpcServerProtocol : BaseServerProtocol!BinServerProtocol
{
    private
    {
        Handler[string] _handlers;
    }


    override void protoConfigure(ApplicationContainer container, Properties config)
    {
        foreach (Properties ctrConf; config.getArray("controller"))
        {
            string ctrName = getNameOrEnforce(ctrConf,
                    "Not defined controller name");

            RpcController ctrl = container.resolveNamed!RpcController(ctrName);
            configEnforce(ctrl !is null, fmt!"Controller '%s' not register"(ctrName));

            ctrl.configure(serializer, ctrConf);

            if (ctrl.enabled)
            {
                ctrl.register(&registerHandler);
                logInfo("Register controller '%s' from '%s'", ctrName, ctrl);
            }
        }
    }


    Bytes handle(Bytes data)
    {
        UniNode uniReq;
        try
            uniReq = serializer.deserialize(data);
        catch (Exception e)
        {
            logWarn("Error deserialize: (%s)", e.msg);
            return serializer.serialize(createErrorBody(null, ErrorCode.PARSE_ERROR, e.msg));
        }

        return serializer.serialize(handleImpl(uniReq));
    }


    bool existstMethod(string cmd)
    {
        return (cmd in _handlers) !is null;
    }


    UniNode execute(string cmd, UniNode params)
    {
        if (auto h = cmd in _handlers)
            return (*h)(params);
        else
            throw new RpcException(ErrorCode.METHOD_NOT_FOUND,
                    getErrorMessageByCode(ErrorCode.METHOD_NOT_FOUND));
    }


    void registerHandler(string cmd, Handler hdl)
    {
        _handlers[cmd] = hdl;
        logInfo("Register method (%s)", cmd);
    }


protected:


    UniNode createErrorHeader(D...)(UniNode* id, int code, string msg, D data)
    {
        UniNode[string] response;
        response["id"] = (id is null) ? UniNode() : *id;
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


    UniNode createErrorBody(D...)(UniNode* id, ErrorCode code, D data)
    {
        return createErrorHeader(id, code, getErrorMessageByCode(code), data);
    }


    UniNode createErrorBody(UniNode* id, RpcException ex)
    {
        return createErrorHeader(id, ex.code, ex.msg, ex.data);
    }


    UniNode createErrorBody(D...)(UniNode* id, int code, string msg, D data)
    {
        return createErrorHeader(id, code, msg, data);
    }


    UniNode createResultBody(UniNode* id, UniNode result)
    {
        if (id is null)
            return UniNode();

        UniNode[string] response;
        response["id"] = *id;
        response["result"] = result;
        return UniNode(response);
    }


private:


    UniNode handleImpl(UniNode uniReq)
    {
        string method;
        UniNode* id;
        UniNode params;

        if (uniReq.type != UniNode.Type.object)
            return createErrorBody(id, ErrorCode.PARSE_ERROR);

        UniNode[string] uniReqMap = uniReq.via.map;
        try
        {
            auto vMethod = "method" in uniReqMap;
            if (!vMethod || !(vMethod.type == UniNode.Type.text
                        || vMethod.type == UniNode.Type.raw))
            {
                logWarn("Not found method");
                return createErrorBody(id, ErrorCode.INVALID_REQUEST,
                        "Parameter method is invalid");
            }

            method = (*vMethod).get!string.strip;
            id = "id" in uniReqMap;
            params = UniNode.emptyObject();
            if (auto pv = "params" in uniReqMap)
                params = *pv;
        }
        catch (Exception e)
        {
            logWarn("Error extract meta info: (%s)", e.msg);
            return createErrorBody(id, ErrorCode.SERVER_ERROR, e.msg);
        }

        if (existstMethod(method))
        {
            try
            {
                UniNode uniRes = execute(method, params);
                return createResultBody(id, uniRes);
            }
            catch (RpcException e)
                return createErrorBody(id, e);
            catch (Exception e)
            {
                logError("Error execute handler: (%s)", e.msg);
                return createErrorBody(id, ErrorCode.SERVER_ERROR, e.msg);
            }
        }
        else
            return createErrorBody(id, ErrorCode.METHOD_NOT_FOUND);
    }
}


/**
 * Клиентсткий протокол Simple
 */
class PlainRpcClientProtocol : RpcClientProtocol
{
    private ulong counterId;


    this(Serializer serializer, ClientTransport transport)
    {
        super(serializer, transport);
    }


    override void protoConfigure(Properties config)
    {
        counterId = 0;
    }


    override final UniNode request(string cmd, UniNode params)
    {
        auto request = createRequest(cmd, params);
        Bytes resData;
        try
        {
            auto reqData = serializer.serialize(request);
            auto futRes = transport.request(reqData);
            resData = futRes.getResult;
        }
        catch (Exception e)
            throw new RpcException(ErrorCode.SERVER_ERROR, e.msg);

        if (resData.length <= 0)
            throw new RpcException(ErrorCode.INTERNAL_ERROR, "Empty response");

        auto response = serializer.deserialize(resData);
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


protected:


    UniNode createRequest(string cmd, UniNode params)
    {
        UniNode[string] request;
        request["id"] = UniNode(++counterId);
        request["method"] = UniNode(cmd);
        request["params"] = params;
        return UniNode(request);
    }
}

