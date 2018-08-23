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

    import proped : Properties;

    import vibe.internal.meta.codegen;
    import vibe.core.log;

    import dango.system.traits;
    import dango.system.container;
    import dango.system.properties : getNameOrEnforce, configEnforce, getOrEnforce;

    import dango.service.serialization;
    import dango.service.protocol.rpc.core;
    import dango.service.protocol.rpc.controller;
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



class ClientFactory(I) : ComponentFactory!(I, Properties, ApplicationContainer)
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

        auto serFactory = container.resolveFactory!(Serializer,
                Properties)(serializerName);
        configEnforce(serFactory !is null,
                fmt!"Serializer '%s' not register"(serializerName));
        Serializer serializer = serFactory.create(serConf);
        logInfo("Use serializer '%s'", serializerName);

        auto trFactory = container.resolveFactory!(ClientTransport,
                Properties)(transportName);
        configEnforce(trFactory !is null,
                fmt!"Transport '%s' not register"(transportName));
        ClientTransport transport = trFactory.create(trConf);
        logInfo("Use transport '%s'", transportName);

        auto protoFactory = container.resolveFactory!(
                RpcClientProtocol, Properties, ClientTransport, Serializer)(protoName);
        configEnforce(protoFactory !is null,
                fmt!"Protocol '%s' not register"(protoName));
        RpcClientProtocol protocol = protoFactory.create(protoConf, transport, serializer);
        logInfo("Use protocol '%s'", protoName);

        return new InterfaceClient!I(protocol);
    }
}


/**
 * Регистрация клиента
 */
void registerClient(TYPE, string NAME)(ApplicationContainer container, Properties config)
{
    alias Client = InterfaceClient!(TYPE);
    alias Factory = ClientFactory!(TYPE);
    container.registerNamed!(TYPE, Client, NAME)
        .factoryInstance!(Factory, TYPE)(CreatesSingleton.yes, config, container);
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
    alias ParameterTypes = ParameterTypeTuple!F;
    enum nameFun = __traits(identifier, F);

    string generateParameterTuple()
    {
        string ret = "Tuple!(";
        foreach(i, key; ParameterIdents)
        {
            alias PType = ParameterTypes[i];
            if (i > 0)
                ret ~= ", ";
            ret ~= "ParameterTypes[" ~ i.to!string ~ "]";
            ret ~= ", \"" ~ key ~ "\"";
        }
        ret ~= ");";
        return ret;
    }

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
        alias ParameterTypes = ParameterTypeTuple!%1$s;
        alias ParameterDefs = ParameterDefaults!%1$s;
        alias RT = ReturnType!%1$s;
        alias PT = %2$s

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
            %3$s
            auto params = serializeToUniNode!PT(args);
        }

        auto result = _protocol.request("%4$s", params);
        return deserializeUniNode!(RT)(result);
    })(nameFun, generateParameterTuple(), generateAssing(), cmd);
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

