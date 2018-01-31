/**
 * Модуль диспетчера
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.dispatcher;

private
{
    import std.functional : toDelegate;
    import std.typecons : Tuple;
    import std.traits;
    import std.format : fmt = format;

    import vibe.core.log;

    import dango.service.serializer : UniNode, Serializer;
    import dango.service.protocol;
}


alias Handler = UniNode delegate(UniNode params);


class Dispatcher
{
    private
    {
        Handler[string] _handlers;
        Serializer _serializer;
    }


    this(Serializer serializer)
    {
        _serializer = serializer;
    }


    bool existst(string cmd)
    {
        return (cmd in _handlers) !is null;
    }


    UniNode handler(string cmd, UniNode params)
    {
        if (auto h = cmd in _handlers)
            return (*h)(params);
        else
            throw new RPCException(createEmptyErrorByCode!UniNode(
                    ErrorCode.METHOD_NOT_FOUND));
    }


    void registerHandler(string cmd, Handler hdl)
    {
        _handlers[cmd] = hdl;
        logInfo("Register method (%s)", cmd);
    }


    template generateHandler(alias F)
    {
        alias ParameterIdents = ParameterIdentifierTuple!F;
        alias ParameterTypes = ParameterTypeTuple!F;
        alias ParameterDefs = ParameterDefaults!F;
        alias Type = typeof(toDelegate(&F));
        alias RT = ReturnType!F;
        alias PT = Tuple!ParameterTypes;

        Handler generateHandler(Type hdl)
        {
            bool[string] requires; // обязательные поля

            UniNode fun(UniNode params)
            {
                if (!(params.type == UniNode.Type.object
                        || params.type == UniNode.Type.array))
                    throw new RPCException(createEmptyErrorByCode!UniNode(
                                ErrorCode.INVALID_PARAMS));

                string[][string] paramErrors;

                // инициализируем обязательные поля
                PT args;
                foreach (i, def; ParameterDefs)
                {
                    string key = ParameterIdents[i];
                    static if (is(def == void))
                        requires[key] = false;
                    else
                        args[i] = def;
                }


                void fillArg(size_t idx, PType)(string key, UniNode value)
                {
                    try
                        args[idx] = _serializer.unmarshal!(PType)(value);
                    catch (Exception e)
                        paramErrors[key] ~= "Got type %s, expected %s".fmt(value.type, typeid(PType));
                }


                foreach(i, key; ParameterIdents)
                {
                    alias PType = ParameterTypes[i];
                    if (params.type == UniNode.Type.object)
                    {
                        if (auto v = key in params)
                        {
                            fillArg!(i, PType)(key, *v);
                            requires[key] = true;
                        }
                    }
                    else if (params.type == UniNode.Type.array)
                    {
                        UniNode[] aParams = params.get!(UniNode[]);
                        if (isArray!PType && ParameterIdents.length == 1)
                        {
                            // import std.stdio: wl = writeln;
                            // wl("set array");
                            fillArg!(i, PType)(key, params);
                            requires[key] = true;
                        }
                        else if (i < aParams.length)
                        {
                            UniNode v = aParams[i];
                            // import std.stdio: wl = writeln;
                            // wl("set position params");
                            // wl(v.type, " -> ", typeid(PType));
                            fillArg!(i, PType)(key, v);
                            requires[key] = true;
                        }
                    }
                }


                foreach (k, v; requires)
                {
                    if (v == false)
                        paramErrors[k] ~= "is required";
                }

                if (paramErrors.length > 0)
                {
                    UniNode[string] errObj;
                    foreach (k, errs; paramErrors)
                    {
                        UniNode[] errArr;
                        foreach (v; errs)
                            errArr ~= UniNode(v);
                        errObj[k] = UniNode(errArr);
                    }
                    throw new RPCException(createErrorByCode!UniNode(
                            ErrorCode.INVALID_PARAMS,
                            UniNode(errObj)));
                }

                // import std.stdio: wl = writeln;
                // wl(args.expand);
                // wl(paramErrors);

                RT ret = hdl(args.expand);
                return _serializer.marshal!RT(ret);
            }

            return &fun;
        }
    }
}