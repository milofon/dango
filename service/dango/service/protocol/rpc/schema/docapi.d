/**
 * Модуль контроллера
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-31
 */

module dango.service.protocol.rpc.schema.docapi;

private
{
    import std.algorithm.iteration : map;
    import std.algorithm.searching : find;
    import std.format : fmt = format;
    import std.array : split, array;

    import dango.service.protocol.rpc.controller;
    import dango.service.protocol.rpc.schema.types;
    import dango.service.protocol.rpc.schema.recorder;
}



struct MethodName
{
    @Doc("Наименование элемента")
    string name;
    @Doc("Дочерние элементы")
    MethodName[] child;
}



@Controller("__schema")
interface ISchemaRpcController
{
    @Method("method.list")
    MethodSchema[] getAllMethods();

    @Method("method.tree")
    MethodName[] getTreeMethodName();

    @Method("method.names")
    string[] getAllMethodNames();

    @Method("method.get")
    MethodSchema getMethod(string name);

    @Method("enum.list")
    EnumSchema[] getAllEnums();

    @Method("enum.names")
    string[] getAllEnumNames();

    @Method("enum.get")
    EnumSchema getEnum(string name);

    @Method("model.list")
    ModelSchema[] getAllModels();

    @Method("model.names")
    string[] getAllModelNames();

    @Method("model.get")
    ModelSchema getModel(string name);
}


/**
 * Контроллер методов документации
 */
class SchemaRpcController : GenericRpcController!(ISchemaRpcController)
{
    private
    {
        SchemaRecorder _recorder;
    }


    this(SchemaRecorder recorder)
    {
        this._recorder = recorder;
    }


    EnumSchema[] getAllEnums()
    {
        return _recorder.getEnums();
    }


    string[] getAllEnumNames()
    {
        return _recorder.getEnums().map!((i) => i.name).array;
    }


    EnumSchema getEnum(string name)
    {
        auto fr = _recorder.getEnums.find!((i) => i.name == name);
        enforceRpc(fr.length, 404, fmt!"Schema for enum '%s' not found"(name));
        return fr[0];
    }


    MethodSchema[] getAllMethods()
    {
        return _recorder.getMethods();
    }


    string[] getAllMethodNames()
    {
        return _recorder.getMethods.map!((i) => i.name).array;
    }


    MethodSchema getMethod(string name)
    {
        auto fr = _recorder.getMethods.find!((i) => i.name == name);
        enforceRpc(fr.length, 404, fmt!"Schema for method '%s' not found"(name));
        return fr[0];
    }


    ModelSchema[] getAllModels()
    {
        return _recorder.getModels;
    }


    string[] getAllModelNames()
    {
        return _recorder.getModels.map!((i) => i.name).array;
    }


    ModelSchema getModel(string name)
    {
        auto fr = _recorder.getModels.find!((i) => i.name == name);
        enforceRpc(fr.length, 404, fmt!"Schema for model '%s' not found"(name));
        return fr[0];
    }


    MethodName[] getTreeMethodName()
    {
        MethodName root;
        auto methodNodes = _recorder.getMethods.map!((m) => m.name.split(".")).array;

        void addNames(ref MethodName node, string[] names)
        {
            if (names.length == 0)
                return;

            auto p = node.child.find!((c) => c.name == names[0]);
            if (p.length > 0)
                addNames(p[0], names[1..$]);
            else
            {
                auto np = MethodName(names[0]);
                addNames(np, names[1..$]);
                node.child ~= np;
            }
        }

        foreach (string[] names; methodNodes)
            addNames(root, names);

        return root.child;
    }
}
