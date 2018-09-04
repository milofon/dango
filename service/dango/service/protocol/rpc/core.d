/**
 * Общий модуль для RPC протоколов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-04
 */

module dango.service.protocol.rpc.core;

public
{
    import dango.service.serialization : Serializer;
    import dango.service.transport.core : ClientTransport;
    import dango.service.protocol.rpc.error : RpcException, ErrorCode;
}

private
{
    import std.string : strip;
    import std.format : fmt = format;

    import vibe.core.log;

    import dango.system.container;
    import dango.system.properties : getNameOrEnforce;

    import uninode.core : UniNode;
    import uniconf.core.exception : configEnforce;

    import dango.service.protocol.core;
    import dango.service.serialization;

    import dango.service.protocol.rpc.error;
    import dango.service.protocol.rpc.controller : RpcController;

    import dango.service.protocol.rpc.schema.recorder;
    import dango.service.protocol.rpc.schema.controller;
}


/**
 * Функция обработки запроса
 */
alias Handler = UniNode delegate(UniNode params);



/**
 * Протокол RPC
 */
interface RpcServerProtocol
{
    /**
     * Регистрация нового обработчика
     * Params:
     * cmd = RPC команда
     * hdl = Обработчик
     */
    void registerHandler(string cmd, Handler hdl);
}


/**
 * Базовый протокол RPC
 */
abstract class BaseRpcServerProtocol : BaseServerProtocol, RpcServerProtocol
{
    private
    {
        Handler[string] _handlers;
    }


    this(Serializer serializer)
    {
        super(serializer);
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

        logDebugV("Request: %s", uniReq);

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
        logInfo("  Register method (%s)", cmd);
    }


protected:


    UniNode createErrorHeader(UniNode* id, int code, string msg, UniNode data);


    UniNode createErrorBody(D...)(UniNode* id, ErrorCode code, D data)
    {
        return createErrorHeader(id, code, getErrorMessageByCode(code),
                createErrorData(data));
    }


    UniNode createErrorBody(D...)(UniNode* id, int code, string msg, D data)
    {
        return createErrorHeader(id, code, msg, createErrorData(data));
    }


    UniNode createErrorBody(UniNode* id, RpcException ex)
    {
        return createErrorHeader(id, ex.code, ex.msg, ex.data);
    }


    UniNode createErrorData(D...)(D data)
    {
        static if (data.length == 1)
        {
            static if (is(D[0] == UniNode))
                return data[0];
            else
                return serializeToUniNode(data[0]);
        }
        else static if (data.length > 1)
        {
            UniNode[] edata;
            foreach (dt; data)
                edata ~= serializeToUniNode(dt);
            return UniNode(edata);
        }
        else
            return UniNode();
    }


    UniNode createResultBody(UniNode* id, UniNode result);


private:


    UniNode handleImpl(UniNode uniReq)
    {
        string method;
        UniNode* id;
        UniNode params;

        if (uniReq.kind != UniNode.Kind.object)
            return createErrorBody(id, ErrorCode.PARSE_ERROR);

        UniNode[string] uniReqMap = uniReq.get!(UniNode[string]);
        try
        {
            auto vMethod = "method" in uniReqMap;
            if (!vMethod || !(vMethod.kind == UniNode.Kind.text
                        || vMethod.kind == UniNode.Kind.raw))
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
            catch (Error e)
            {
                logError("FATAL Error execute handler: (%s)", e.msg);
                return createErrorBody(id, ErrorCode.SERVER_ERROR, e.msg);
            }
        }
        else
            return createErrorBody(id, ErrorCode.METHOD_NOT_FOUND);
    }
}


/**
 * Фабрика протокола RPC
 */
class RpcServerProtocolFactory(CType : RpcServerProtocol) : BaseServerProtocolFactory
{
    ServerProtocol createComponent(Config config, ApplicationContainer container,
            Serializer serializer)
    {
        auto ret = new CType(serializer);
        auto schemaRec = new SchemaRecorder();

        foreach (Config ctrConf; config.getArray("controller"))
        {
            string ctrName = getNameOrEnforce(ctrConf,
                    "Not defined controller name");

            auto ctrlFactory = container.resolveFactory!(RpcController, Config)(ctrName);
            configEnforce(ctrlFactory !is null,
                    fmt!"RPC controller '%s' not register"(ctrName));

            RpcController ctrl = ctrlFactory.create(ctrConf);
            configEnforce(ctrl !is null,
                    fmt!"RPC controller factory '%s' return null"(ctrName));

            if (ctrl.enabled)
            {
                logInfo("Register controller '%s' from '%s'", ctrName, ctrl);
                ctrl.registerHandlers(&ret.registerHandler);
                ctrl.registerSchema(schemaRec);
            }
        }

        auto docCtrl = new SchemaRpcController(schemaRec);
        if (config.getOrElse("schemaInclude", false))
            docCtrl.registerSchema(schemaRec);
        logInfo("Register controller '%s' from '%s'", "rpcdoc", docCtrl);
        docCtrl.registerHandlers(&ret.registerHandler);

        return ret;
    }
}


/**
 * Клиент-протокол RPC
 */
interface RpcClientProtocol
{
    UniNode request(string cmd, UniNode params);
}


/**
 * Клиент-протокол RPC
 */
abstract class BaseRpcClientProtocol : RpcClientProtocol
{
    protected
    {
        ClientTransport _transport;
        Serializer _serializer;
    }


    this(ClientTransport transport, Serializer serializer)
    {
        this._serializer = serializer;
        this._transport = transport;
    }


    UniNode request(string cmd, UniNode params)
    {
        auto request = createRequest(cmd, params);
        Bytes resData;
        try
        {
            auto reqData = _serializer.serialize(request);
            auto futRes = _transport.request(reqData);
            resData = futRes.getResult;
        }
        catch (Exception e)
            throw new RpcException(ErrorCode.SERVER_ERROR, e.msg);

        if (resData.length <= 0)
            throw new RpcException(ErrorCode.INTERNAL_ERROR, "Empty response");

        auto response = _serializer.deserialize(resData);
        return parseResponse(response);
    }


protected:


    UniNode createRequest(string cmd, UniNode params);


    UniNode parseResponse(UniNode response);
}


/**
 * Фабрика Клиент-протокола RPC
 */
class RpcClientProtocolFactory(T : RpcClientProtocol) : ComponentFactory!(
        RpcClientProtocol, Config, ClientTransport, Serializer)
{
    RpcClientProtocol createComponent(Config config, ClientTransport transport,
            Serializer serializer)
    {
        return new T(transport, serializer);
    }
}

