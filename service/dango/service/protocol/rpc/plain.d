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
}


/**
 * Протокол Simple
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
            return serializer.serialize(createErrorBody(ErrorCode.PARSE_ERROR, e.msg));
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


    UniNode createErrorHeader(D...)(int code, string msg, D data)
    {
        UniNode[string] response;
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


    UniNode createErrorBody(D...)(ErrorCode code, D data)
    {
        return createErrorHeader(code, getErrorMessageByCode(code), data);
    }


    UniNode createErrorBody(RpcException ex)
    {
        return createErrorHeader(ex.code, ex.msg, ex.data);
    }


    UniNode createErrorBody(D...)(int code, string msg, D data)
    {
        return createErrorHeader(code, msg, data);
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
            return createErrorBody(ErrorCode.PARSE_ERROR);

        UniNode[string] uniReqMap = uniReq.via.map;
        try
        {
            auto vMethod = "method" in uniReqMap;
            if (!vMethod || !(vMethod.type == UniNode.Type.text
                        || vMethod.type == UniNode.Type.raw))
            {
                logWarn("Not found method");
                return createErrorBody(ErrorCode.INVALID_REQUEST,
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
            return createErrorBody(ErrorCode.SERVER_ERROR, e.msg);
        }

        if (existstMethod(method))
        {
            try
            {
                UniNode uniRes = execute(method, params);
                return createResultBody(id, uniRes);
            }
            catch (RpcException e)
                return createErrorBody(e);
            catch (Exception e)
            {
                logError("Error execute handler: (%s)", e.msg);
                return createErrorBody(ErrorCode.SERVER_ERROR, e.msg);
            }
        }
        else
            return createErrorBody(ErrorCode.METHOD_NOT_FOUND);
    }
}

