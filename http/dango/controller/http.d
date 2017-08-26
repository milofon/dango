/**
 * Модуль для генерации http обработчиков
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.controller.http;

public
{
    import vibe.http.router : URLRouter;
    import vibe.http.server : HTTPServerRequest, HTTPServerResponse, HTTPServerRequestDelegate;
}

private
{
    import std.traits : getUDAs;
    import std.meta : Alias;

    import vibe.core.path : Path;

    import dango.controller.core;
}


/**
 * Аннотация для обозначение объекта контроллера
 * Params:
 *
 * prefix = Префикс для всех путей
 */
struct HTTPController
{
    string prefix;
}


/**
 * Аннотация для обозначения метода для обработки входящих запросов
 * Params:
 *
 * path   = Путь
 * method = Метод
 */
struct HTTPHandler
{
    string path;
    HTTPMethod method = HTTPMethod.GET;
}


/**
 * Аннотация для составления документации к методу
 * Params:
 *
 * helpText = Справочная информация о методе
 * params   = Информация о принимаемых параметрах в URL
 * query    = Информация о передаваемых параметрах запроса GET
 */
struct HTTPHandlerInfo
{
    string helpText;
    string[string] params;
    string[string] query;
}


/**
 * Аннотация для обозначения метода или контроллера
 * доступ к которым осуществляется только авторизованными пользователями
 */
enum Auth;


template isHTTPController(C)
{
    enum isHTTPController = is(C == class);
}


alias RegisterHandler(T) = void delegate(HTTPMethod, string, T);


string getHandlerPath(C)(string path)
{
    auto udas = getUDAs!(C, HTTPController);
    static if (udas.length > 0)
    {
        string prefix = udas[0].prefix;
        Path p = Path(prefix);
        p ~= (Path(path)).nodes;
        return p.toString();
    }
    else
        return path;
}


void registerController(C, Handler)(URLRouter router, C controller, RegisterHandler!Handler handler)
    if (isHTTPController!C)
{
    foreach (string fName; __traits(allMembers, C))
    {
        enum access = __traits(getProtection, __traits(getMember, C, fName));
        static if (access == "public")
        {
            alias member = Alias!(__traits(getMember, C, fName));
            foreach (attr; __traits(getAttributes, member))
            {
                static if (is(typeof(attr) == HTTPHandler))
                {
                    alias Type = typeof(&__traits(getMember, controller, fName));
                    static assert(is(Type == Handler), "Handler '" ~ fName ~ "' does not match the type");
                    handler(attr.method, getHandlerPath!C(attr.path),
                            &__traits(getMember, controller, fName));
                }
            }
        }
    }
}


/**
 * Функция стоит объект настроект http сервера по параметрам конфигурации
 * Params:
 *
 * config = Конфигурация
 */
HTTPServerSettings loadServiceSettings(Properties config)
{
    HTTPServerSettings settings = new HTTPServerSettings();

    string host = config.getOrElse("host", "0.0.0.0");
    settings.bindAddresses = [host];

    auto port = config.get!long("port");
    if (port.isNull)
        throw new PropertiesNotFoundException(config, "port");
    settings.port = cast(ushort)port.get;

    HTTPServerOption options = HTTPServerOption.parseURL | HTTPServerOption.parseQueryString | HTTPServerOption.parseCookies;
    if ("options" in config)
        options.setOptionsByName!(HTTPServerOption,
                "distribute",
                "errorStackTraces"
                )(config.sub("options"));

    settings.options = options;

    if ("hostName" in config)
        settings.hostName = config.get!string("hostName");

    if ("maxRequestTime" in config)
        settings.maxRequestTime = dur!"seconds"(config.get!long("maxRequestTime"));

    if ("keepAliveTimeout" in config)
        settings.keepAliveTimeout = dur!"seconds"(config.get!long("keepAliveTimeout"));

    if ("maxRequestSize" in config)
        settings.maxRequestSize = config.get!long("maxRequestSize");

    if ("maxRequestHeaderSize" in config)
        settings.maxRequestHeaderSize = config.get!long("maxRequestHeaderSize");

    if ("accessLogFormat" in config)
        settings.accessLogFormat = config.get!string("accessLogFormat");

    if ("accessLogFile" in config)
        settings.accessLogFile = config.get!string("accessLogFile");

    settings.accessLogToConsole = config.getOrElse("accessLogToConsole", false);

    if ("ssl" in config)
    {
        Properties sslConfig = config.sub("ssl");
        settings.tlsContext = createTLSContextFrom(sslConfig);
    }

    return settings;
}


/**
 * Создание TLS контекста из конфигурации сервиса
 */
TLSContext createTLSContextFrom(Properties sslConfig)
{
    TLSContext tlsCtx = createTLSContext(TLSContextKind.server);

    auto certChainFile = sslConfig.get!string("certificateChainFile");
    auto privateKeyFile = sslConfig.get!string("privateKeyFile");

    if (certChainFile.isNull)
        throw new PropertiesNotFoundException(sslConfig, "certificateChainFile");

    if (privateKeyFile.isNull)
        throw new PropertiesNotFoundException(sslConfig, "privateKeyFile");

    tlsCtx.useCertificateChainFile(certChainFile.get);
    tlsCtx.usePrivateKeyFile(privateKeyFile.get);

    return tlsCtx;
}


/**
 * Установка свойства в битовую маску
 */
void setOption(T)(ref T options, bool flag, T value)
{
    if (flag)
        options |= value;
    else
        options &= ~value;
}


/**
 * Установка свойства в битовую маску по имени свойства
 */
void setOptionByName(T, string name)(ref T options, Properties config)
{
    if (name in config)
        options.setOption(config.get!bool(name), __traits(getMember, T, name));
}


/**
 * Установка массива свойств в битовую маску
 */
void setOptionsByName(T, NAMES...)(ref T options, Properties config)
{
    foreach(string name; NAMES)
        options.setOptionByName!(T, name)(config);
}

