/**
 * Модуль контроллера
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-31
 */

module dango.service.protocol.rpc.schema.controller;

private
{
    import std.algorithm.iteration : uniq, fold, map;
    import std.algorithm.searching : find;
    import std.algorithm.sorting : sort;
    import std.array : appender, Appender, array, split;
    import std.format : fmt = format;

    import dango.service.protocol.rpc.controller;
    import dango.service.protocol.rpc.schema.types;
    import dango.service.serialization : marshalObject;
}


struct Item
{
    @Doc("Дочерние элементы")
    Item[string] child;
}


@Controller("__schema")
interface IDocumataionRpcController
{
    @Method("method.tree")
    Item[string] getTreeMethods();

    @Method("method.list")
    MethodDoc[] getAllMethods();

    @Method("method.get")
    MethodDoc getMethod(string name);

    @Method("model.list")
    ModelDoc[] getAllModels();

    @Method("model.get")
    ModelDoc getModel(string name);
}


/**
 * Контроллер методов документации
 */
class DocumataionRpcController : GenericRpcController!IDocumataionRpcController
{
    private
    {
        Appender!(MethodDoc[]) _methods;
        Appender!(ModelDoc[]) _allModels;

        bool _initialized;
        ModelDoc[] _models;
    }


    void registerMethod(MethodDoc md)
    {
        _methods.put(md);
    }


    void registerModel(ModelDoc[] td)
    {
        _allModels.put(td);
    }


    MethodDoc[] getAllMethods()
    {
        return _methods.data;
    }


    MethodDoc getMethod(string name)
    {
        auto md = _methods.data.find!((m) => m.method == name);
        enforceRpc(md.length, 404, fmt!"Documentation method '%s' not found"(name));
        return md[0];
    }


    ModelDoc[] getAllModels()
    {
        initialize();
        return _models;
    }


    ModelDoc getModel(string name)
    {
        initialize();
        auto td = _models.find!((t) => t.name == name);
        enforceRpc(td.length, 404, fmt!"Documentation type '%s' not found"(name));
        return td[0];
    }


    Item[string] getTreeMethods()
    {
        auto methodNodes = _methods.data.map!((m) => m.method.split(".")).array;
        Item root;

        void addNames(ref Item node, string[] names)
        {
            if (names.length == 0)
                return;

            if (auto p = names[0] in node.child)
                addNames(*p, names[1..$]);
            else
            {
                auto p = Item();
                addNames(p, names[1..$]);
                node.child[names[0]] = p;
            }
        }

        foreach (string[] names; methodNodes)
            addNames(root, names);

        return root.child;
    }


private:


    void initialize()
    {
        if (_initialized)
            return;

        _models = _allModels.data
            .sort!((a, b) => a.name > b.name)
            .uniq!((a, b) => a.name == b.name)
            .array;

        _initialized = true;
    }
}

