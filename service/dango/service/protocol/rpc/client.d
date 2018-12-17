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

    import uninode.core : UniNode;
    import uniconf.core : Config;
    import poodinis : Registration;
    import vibe.internal.meta.codegen;
    import vibe.core.log;

    import dango.system.traits : IsPublicMember;
    import dango.system.container;
    import dango.system.properties : getNameOrEnforce;
    import uniconf.core.exception : enforceConfig;

    import dango.service.protocol.rpc.core : RpcClientProtocol;
    import dango.service.protocol.rpc.controller;

    import dango.service.serialization;
    import dango.service.transport;
}


/**
 * Класс донор для клиента
 */
class InterfaceClient(I) : I
{
    static assert(is(I == interface),
            I.stringof ~ " is not interface");

    static assert(hasUDA!(I, Controller),
            I.stringof ~ " is not marked with a Controller");

    private RpcClientProtocol _protocol;


    this(RpcClientProtocol protocol)
    {
        this._protocol = protocol;
    }

    static foreach(Member; GetRpcControllerMethods!I)
        mixin GenerateFunctionFromMember!(I, Member);
}


/**
 * Регистрация клиента
 */
Registration registerClient(I, string NAME)(ApplicationContainer container, Config config)
{
    alias Client = InterfaceClient!(I);
    alias Factory = ClientFactory!(I, Client);
    return container.registerNamed!(I, Client, NAME)
        .factoryInstance!Factory(config, container);
}


/**
 * Фабрика для клиента
 */
class ClientFactory(I, C) : ComponentFactory!(I, Config, ApplicationContainer)
{
    C createComponent(Config config, ApplicationContainer container)
    {
        Config trConf = config.getOrEnforce!Config("transport",
                "Not defined client transport config");
        Config serConf = config.getOrEnforce!Config("serializer",
                "Not defined client serializer config");
        Config protoConf = config.getOrEnforce!Config("protocol",
                "Not defined client protocol config");

        string serializerName = serConf.getNameOrEnforce(
                "Not defined client serializer name");
        string protoName = protoConf.getNameOrEnforce(
                "Not defined client protocol name");
        string transportName = trConf.getNameOrEnforce(
                "Not defined clien transport name");

        auto serFactory = container.resolveNamedFactory!Serializer(serializerName,
                ResolveOption.noResolveException);
        enforceConfig(serFactory !is null,
                fmt!"Serializer '%s' not register"(serializerName));

        auto trFactory = container.resolveNamedFactory!ClientTransport(
                transportName, ResolveOption.noResolveException);
        enforceConfig(trFactory !is null,
                fmt!"Transport '%s' not register"(transportName));

        auto protoFactory = container.resolveNamedFactory!RpcClientProtocol(
                protoName, ResolveOption.noResolveException);
        enforceConfig(protoFactory !is null,
                fmt!"Protocol '%s' not register"(protoName));

        Serializer serializer = serFactory.createInstance(serConf);
        ClientTransport transport = trFactory.createInstance(trConf);
        RpcClientProtocol protocol = protoFactory.createInstance(protoConf,
                transport, serializer);

        return new C(protocol);
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
            auto parameters = UniNode();
        else
        {
            PT args;
            foreach (i, def; ParameterDefs)
            {
                static if (!is(def == void))
                    args[i] = def;
            }
            %3$s
            auto parameters = serializeToUniNode!PT(args);
        }

        auto result = _protocol.request("%4$s", parameters);

        static if (!is(RT == void))
            return deserializeUniNode!(RT)(result);
    })(nameFun, generateParameterTuple(), generateAssing(), cmd);
}



string GenerateModuleImports(I)()
{
    if (!__ctfe)
        assert (false);

    import vibe.internal.meta.codegen : getRequiredImports;
    import std.algorithm : map;
    import std.array : join;

    auto modules = getRequiredImports!I();
    return join(map!(a => "static import " ~ a ~ ";")(modules), "\n");
}

