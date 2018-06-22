/**
 * Реализация протокола GraphQL
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-18
 */

module dango.service.protocol.graphql.proto;

private
{
    import dango.service.protocol.core;
}


/**
 * Протокол GraphQL
 */
class GraphQLServerProtocol : BaseServerProtocol!BinServerProtocol
{
    override void protoConfigure(ApplicationContainer container, Properties config)
    {

    }


    Bytes handle(Bytes data)
    {
        return data;
    }
}
