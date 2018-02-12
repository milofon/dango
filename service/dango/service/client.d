/**
 * Модуль содержит компоненты для построения клиентов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-02-11
 */

module dango.service.client;

public
{
    import dango.service.controller : RpcController, RpcHandler;
}

private
{
    import std.traits;
    import std.format : fmt = format;
    import std.meta;
    import std.conv : to;

    import vibe.internal.meta.codegen;

    import dango.system.traits;
    import dango.service.protocol;
    import dango.service.serializer;
}



class InterfaceClient(I) : I
{
    import std.typecons : Tuple;

    private
    {
        RpcClientProtocol _protocol;
    }


    this(RpcClientProtocol protocol)
    {
        _protocol = protocol;
    }


    // pragma(msg, generateModuleImports!I());
    mixin(generateModuleImports!I());
    // pragma(msg, generateMethodHandlers!I);
    mixin (generateMethodHandlers!I);
}


/**
 * Генерация клиента
 */
InterfaceClient!I createRpcClient(I)(RpcClientProtocol protocol)
{
    return new InterfaceClient!(I)(protocol);
}


private:


string generateMethodHandlers(I)()
{
    string getFullMethod(string method)
    {
        enum udas = getUDAs!(I, RpcController);
        static if (udas.length > 0)
        {
            string prefix = udas[0].prefix;
            if (prefix.length > 0)
                return prefix ~ "." ~ method;
            else
                return method;
        }
        else
            return method;
    }

	string ret = q{
		import vibe.internal.meta.codegen : CloneFunction;
    };

    foreach (string fName; __traits(allMembers, I))
    {
        static if(IsPublicMember!(I, fName))
        {
            alias member = Alias!(__traits(getMember, I, fName));
            static if (isCallable!member)
            {
                foreach (attr; __traits(getAttributes, member))
                {
                    static if (is(typeof(attr) == RpcHandler))
                    {
                        ret ~= `mixin CloneFunction!(` ~ fName ~ `, q{` ~
                            generateMethodHandler!(I, fName)(getFullMethod(attr.method))
                        ~ `});
                        `;
                    }
                }
            }
        }
    }

    return ret;
}



string generateMethodHandler(I, string fName)(string cmd)
{
    alias member = Alias!(__traits(getMember, I, fName));
    alias ParameterIdents = ParameterIdentifierTuple!member;
    alias ParameterTypes = ParameterTuple!member;

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
            ret ~= "args." ~ key ~ " = " ~ key ~ ";\n";
        }
        return ret;
    }

    return q{
        alias ParameterIdents = ParameterIdentifierTuple!%1$s;
        alias ParameterTypes = ParameterTuple!%1$s;
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
            auto params = marshalObject!PT(args);
        }

        auto result = _protocol.request("%4$s", params);
        return unmarshalObject!(RT)(result);
    }.fmt(fName, generateParameterTuple(), generateAssing(), cmd);
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
