/**
 * Модуль реализации системы документирования RPC
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-12
 */

module dango.service.protocol.rpc.schema.parser;

private
{
    import std.string : outdent;
    import dango.service.protocol.rpc.schema.types;
}



void parseDocumentationContent(ref MethodDoc md, string comment)
{
    md.note = "not implemented parse content";
}

