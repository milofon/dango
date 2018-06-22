/**
 * Модуль содержит компоненты для построения клиентов RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-22
 */

module dango.service.protocol.rpc.client;

private
{
    import std.traits;
    import std.meta : Alias;
    import std.format : fmt = format;
    import std.typecons : Tuple;
    import std.functional : toDelegate;
    import std.conv : to;

    import vibe.internal.meta.codegen;

    import dango.system.traits;

    import dango.service.serialization;
    import dango.service.transport.core : ClientTransport;
    import dango.service.protocol.rpc.controller : Method, Controller, FullMethodName;
    import dango.service.protocol.core : BaseClientProtocol;
}


/**
 * Базовый класс клиентского протокола взаимодействия RPC
 */
abstract class RpcClientProtocol : BaseClientProtocol
{
    this(Serializer serializer, ClientTransport transport)
    {
        super(serializer, transport);
    }


    UniNode request(string cmd, UniNode params);
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

    mixin(generateModuleImports!I());
    mixin eachControllerMethods!(I);
}


private:


mixin template eachControllerMethods(I)
{
    static foreach (string fName; __traits(allMembers, I))
    {
        static if(IsPublicMember!(I, fName))
        {
            alias member = Alias!(__traits(getMember, I, fName));
            enum udas = getUDAs!(member, Method);

            static if (isCallable!member && udas.length > 0)
            {
                enum cmd = FullMethodName!(I, udas[0].method);
                mixin CloneFunction!(member, GenerateHandlerFromMethod!(member, cmd));
            }
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

