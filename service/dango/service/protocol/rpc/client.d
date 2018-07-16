/**
 * Модуль содержит компоненты для построения клиентов RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-15
 */

module dango.service.protocol.rpc.client;

private
{
    import std.traits;
    import std.meta : Alias, AliasSeq;
    import std.format : fmt = format;
    import std.typecons : Tuple;
    import std.conv : to;

    import vibe.internal.meta.codegen;
    import vibe.core.log;

    import dango.system.traits;
    import dango.system.container;
    import dango.system.properties : getNameOrEnforce, configEnforce, getOrEnforce;

    import dango.service.protocol.rpc.core;
    import dango.service.protocol.rpc.controller;
    import dango.service.serialization : UniNode,
           marshalObject, unmarshalObject;
}


/**
 * Класс донор для клиента
 */
class InterfaceClient(I) : I
{
    private RpcClientProtocol _protocol;


    this(RpcClientProtocol protocol)
    {
        this._protocol = protocol;
    }


    static foreach(Member; GetRpcControllerMethods!I)
        mixin GenerateFunctionFromMember!(I, Member);


    mixin(generateModuleImports!I());
}



class ClientFactory(I) : ComponentFactory!(I, ApplicationContainer)
{
    InterfaceClient!I createComponent(Properties config, ApplicationContainer container)
    {
        Properties trConf = config.getOrEnforce!Properties("transport",
                "Not defined client transport config");
        Properties serConf = config.getOrEnforce!Properties("serializer",
                "Not defined client serializer config");
        Properties protoConf = config.getOrEnforce!Properties("protocol",
                "Not defined client protocol config");

        string serializerName = getNameOrEnforce(serConf,
                "Not defined client serializer name");
        string protoName = getNameOrEnforce(protoConf,
                "Not defined client protocol name");
        string transportName = getNameOrEnforce(trConf,
                "Not defined clien transport name");

        auto serFactory = container.resolveFactory!Serializer(serializerName);
        configEnforce(serFactory !is null,
                fmt!"Serializer '%s' not register"(serializerName));
        Serializer serializer = serFactory.create(serConf);
        logInfo("Use serializer '%s'", serializerName);

        auto trFactory = container.resolveFactory!(ClientTransport)(transportName);
        configEnforce(trFactory !is null,
                fmt!"Transport '%s' not register"(transportName));
        ClientTransport transport = trFactory.create(trConf);
        logInfo("Use transport '%s'", transportName);

        auto protoFactory = container.resolveFactory!(
                RpcClientProtocol, ClientTransport, Serializer)(protoName);
        configEnforce(protoFactory !is null,
                fmt!"Protocol '%s' not register"(protoName));
        RpcClientProtocol protocol = protoFactory.create(protoConf, transport, serializer);
        logInfo("Use protocol '%s'", protoName);

        return new InterfaceClient!I(protocol);
    }
}


private:


mixin template GenerateFunctionFromMember(IType, alias Member)
{
    enum fName = __traits(identifier, Member);
    static if(IsPublicMember!(IType, fName))
    {
        enum udas = getUDAs!(Member, Method);
        static if (isCallable!Member && udas.length > 0)
        {
            enum cmd = FullMethodName!(IType, udas[0].method);
            mixin CloneFunction!(Member, GenerateHandlerFromMethod!(Member, cmd));
        }
    }
}



template GenerateHandlerFromMethod(alias F, string cmd)
{
    alias ParameterIdents = ParameterIdentifierTuple!F;
    alias ParameterTypes = ParameterTuple!F;
    enum nameFun = __traits(identifier, F);

    string generateAssing()
    {
        string ret;
        foreach(i, key; ParameterIdents)
        {
            alias PType = ParameterTypes[i];
            ret ~= "args[" ~ i.to!string ~ "] = " ~ key ~ ";\n";
        }
        return ret;
    }

    enum GenerateHandlerFromMethod = fmt!(q{
        alias ParameterIdents = ParameterIdentifierTuple!%1$s;
        alias ParameterTypes = ParameterTuple!%1$s;
        alias ParameterDefs = ParameterDefaults!%1$s;
        alias RT = ReturnType!%1$s;
        alias PT = Tuple!ParameterTypes;

        static if (ParameterIdents.length == 0)
            auto params = UniNode();
        else
        {
            PT args;
            foreach (i, def; ParameterDefs)
            {
                static if (!is(def == void))
                    args[i] = def;
            }
            %2$s
            auto params = marshalObject!PT(args);
        }

        auto result = _protocol.request("%3$s", params);
        return unmarshalObject!(RT)(result);
    })(nameFun, generateAssing(), cmd);
}



string generateModuleImports(I)()
{
    if (!__ctfe)
        assert (false);

    import vibe.internal.meta.codegen : getRequiredImports;
    import std.algorithm : map;
    import std.array : join;

    auto modules = getRequiredImports!I();
    return join(map!(a => "static import " ~ a ~ ";")(modules), "\n");
}

