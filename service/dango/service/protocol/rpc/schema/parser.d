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
    import std.array : array;
    import std.algorithm.comparison : among;
    import std.algorithm.sorting : sort;
    import std.algorithm.iteration : map, uniq;

    import vibe.core.log : logWarn;

    import dparse.lexer;
    import std.experimental.lexer;

    import dango.service.protocol.rpc.schema.types;
}


/**
 * Парсер документации метода
 */
void parseDocumentationContent(ref MethodSchema md, string comment)
{
    auto lexer = makeLexer(comment);

    if (!isKeyword(lexer.front))
        md.summary = lexer.parseSingleLine();

    if (!isKeyword(lexer.front))
        md.description = lexer.parseTextBlock();

    while (!lexer.empty)
    {
        switch(lexer.front.type)
        {
            case tok!"Params:":
                auto params = lexer.parseParamsBlock();

                foreach(name, _; md.params)
                {
                    if (name in params)
                        md.params[name].note = params[name];
                    else
                        logWarn("Doc: Missing description for parameter `%s` in `%s`", name, md.name);
                }
                break;

            case tok!"Returns:":
                lexer.popFront();
                md.retType.note = lexer.parseTextBlock();
                break;

            case tok!"whitespace":
            case tok!"emptyline":
            default:
                lexer.popFront();
        }
    }
}


private:


/**
  * Пропуск всех указанных токенов
  */
void skipAll(T...)(ref DocLexer lexer)
{
    while (!lexer.empty)
    {
        switch (lexer.front.type)
        {
            static foreach(t; T)
            {
                case t:
            }
                lexer.popFront();
                break;

            default:
                return;
        }
    }
}


/**
  * Пропуск всех токенов кроме переданных
  */
void skipUntil(T...)(ref DocLexer lexer)
{
    while (!lexer.empty)
    {
        switch (lexer.front.type)
        {
            static foreach(t; T)
            {
                case t:
            }
                return;

            default:
                lexer.popFront();
        }
    }
}


/**
 * Спарсить одну строку
 */
string parseSingleLine(ref DocLexer lexer)
{
    string line = "";

    lexer.skipUntil!(tok!"string", toks!keywords);

    while (!lexer.empty && lexer.front.type.among(tok!"string", tok!"whitespace"))
    {
        if (lexer.front.type == tok!"string")
        {
            if (line.length)
                line ~= " ";
            line ~= lexer.front.text;
        }
        lexer.popFront();
    }

    return line;
}


/**
 * Спарсить блок текста
 */
string parseTextBlock(ref DocLexer lexer)
{
    string text = "";
    bool newlined = true;

    lexer.skipUntil!(tok!"string", toks!keywords);

    while (!lexer.empty && !isKeyword(lexer.front))
    {
        if (lexer.front.type == tok!"string")
        {
            if (text.length && !newlined)
                text ~= " ";
            if (text.length && newlined)
                text ~= "\n";

            text ~= lexer.front.text;
            newlined = false;
        }

        if (lexer.front.type == tok!"emptyline")
            newlined = true;

        lexer.popFront();
    }

    return text;
}


/**
 * Спарсить блок описания параметров
 */
string[string] parseParamsBlock(ref DocLexer lexer)
{
    import std.regex : ctRegex, matchFirst;

    string[] paramsStr = [];

    // Skip 'Params:'
    lexer.popFront();

    while (!lexer.empty && !isKeyword(lexer.front))
    {
        if (lexer.front.type == tok!"string")
            paramsStr ~= lexer.front.text;
        lexer.popFront();
    }

    string[string] params;
    foreach(str; paramsStr)
    {
        auto exp = ctRegex!(r"^[\s]*([\S]+)[\s]*=[\s]*(.+)$");
        auto match = matchFirst(str, exp);
        if (!match.empty)
            params[match[1]] = match[2];
        else
            logWarn("Doc: Unparsable parameter description `%s`", str);
    }

    return params;
}



bool isKeyword(Token token)
{
    switch(token.type)
    {
        static foreach(key; keywords)
        case tok!key:
            return true;
        default:
            return false;
    }
}


/**
 * Создание лексера языка документации
 */
DocLexer makeLexer(string comment)
{
    StringCache* cache = new StringCache(StringCache.defaultBucketCount);
    return DocLexer(cast(ubyte[])comment, cache);
}


/**
 * Фиксированные токены языка документации
 */
private enum fixedTokens = cast(string[]) [];


/**
 * Динамические токены языка документации
 */
private enum dynamicTokens = [
    "string", // Строка текста
    "whitespace", // Пробельные символы
    "emptyline" // Пустые строки
];


/**
 * Ключевые слова языка документации
 */
private enum keywords = [
    "Params:", "Returns:"
];


/**
 * Обработчики токенов
 */
private enum tokenHandlers = [
    " ", "lexWhitespace",
    "\t", "lexWhitespace",
    "\r", "lexTryEmptyline",
    "\n", "lexTryEmptyline"
];


alias IdType = TokenIdType!(fixedTokens, dynamicTokens, keywords);


public alias str = tokenStringRepresentation!(IdType, fixedTokens, dynamicTokens, keywords);


template tok(string token)
{
    alias tok = TokenId!(IdType, fixedTokens, dynamicTokens, keywords, token);
}


template toks(tokens...)
{
    import std.meta : aliasSeqOf, staticMap;

    alias toks = staticMap!(tok, aliasSeqOf!(tokens));
}


enum extraFields = "";


alias Token = TokenStructure!(IdType, extraFields);


/**
  * Лексер языка документации
  */
struct DocLexer
{
    mixin Lexer!(Token, lexString, isSeparating, fixedTokens,
        dynamicTokens, keywords, tokenHandlers);


    this(ubyte[] source, StringCache* cache)
    {
        this.range = source;
        this.cache = cache;
        popFront();
    }


    void popFront() pure
    {
        _popFront();
    }


private:


    bool isSpace(dchar c) pure nothrow @safe
    {
        import std.uni : isWhite;
        return isWhite(c) && c != '\r' && c != '\n';
    }


    void lexWhitespace(ref Token token) pure nothrow @safe
    {
        mixin (tokenStart);

        while (!range.empty && isSpace(range.front))
            range.popFront();

        mixin(getText);
        token = Token(tok!"whitespace", text, line, column, index);
    }


    void lexTryEmptyline(ref Token token) pure nothrow @safe
    {
        import std.ascii : isWhite;

        mixin (tokenStart);

        int newlines = 0;

        while (!range.empty && isWhite(range.front))
            switch(range.front)
            {
                case '\r':
                    range.popFront();
                    if (!range.empty && range.front == '\n')
                        range.popFront();
                    range.incrementLine();
                    newlines++;
                    break;
                case '\n':
                    range.popFront();
                    range.incrementLine();
                    newlines++;
                    break;
                default:
                    range.popFront();
            }

        mixin(getText);

        if (newlines > 1)
            token = Token(tok!"emptyline", text, line, column, index);
        else
            token = Token(tok!"whitespace", text, line, column, index);
    }


    void lexString(ref Token token) pure nothrow @safe
    {
        mixin (tokenStart);
        while (true)
        {
            if (range.empty)
                break;

            if (range.front == '\n')
                break;

            range.popFront();
        }

        mixin(getText);
        token = Token(tok!"string", text, line, column, index);
    }


    bool isSeparating(size_t offset) pure nothrow @safe
    {
        return true;
    }



    enum tokenStart = q{
        size_t line = range.line;
        size_t column = range.column;
        size_t index = range.index;
        auto mark = range.mark();
    };


    enum getText = q{
        string text = cache.intern(range.slice(mark));
    };


    StringCache* cache;
}
