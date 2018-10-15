/**
 * Модуль обработки командной строки
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.commandline;

private
{
    import std.array: split;
    import std.getopt;
    import std.process: environment;
    import std.traits: isArray, isNarrowString;
    import std.conv : to;

    import uniconf.core.config : Config;
}


private template ValueTuple(T...) { alias ValueTuple = T; }

private alias getoptConfig = ValueTuple!(std.getopt.config.passThrough, std.getopt.config.bundling);

private alias getoptRequireConfig = ValueTuple!(std.getopt.config.passThrough, std.getopt.config.bundling, std.getopt.config.required);


/**
 * Процессор для обработки командной строки
 */
class CommandLineProcessor
{
    private
    {
        string[] args;
        Option[] options;
        Config config;

        bool helpWanted;
        bool errorWanted;
    }


    this(string[] args)
    {
        this.config = Config.emptyObject;
        this.args = args;
    }


    private Option splitAndGet(string names) pure nothrow
    {
        auto sp = split(names, "|");
        Option ret;
        if (sp.length > 1)
        {
            ret.optShort = "-" ~ (sp[0].length < sp[1].length ?
                    sp[0] : sp[1]);

            ret.optLong = "--" ~ (sp[0].length > sp[1].length ?
                    sp[0] : sp[1]);
        }
        else
        {
            ret.optLong = "--" ~ sp[0];
        }

        return ret;
    }


    private void addProperties(T)(string key, T value)
    {
        static if (isNarrowString!T)
            config[key] = Config(value);
        else static if (isArray!T)
        {
            Config[] arr;
            foreach(item; value)
                arr ~= Config(item);
            config[key] = Config(arr);
        }
        else
            config[key] = Config(value.to!string);
    }

    /**
     * Чтение аргумента из командной строки при помощи стандартных стредств phobos
     *
     * Params:
     *
     * names        = Считываемые с командной строки аргументы
     * value        = Ссылка на переменную в которую будет установлено заначение
     * helpText     = Текст справки
     * required     = Флаг обязательности аргумента
     * propertyPath = Путь, по которому будет установлено значение в конфиге
     *
     * Example:
     * --------------------
     * readOption("config|c", &configFiles, "Конфиг файлы", false, "trand.config");
     * --------------------
     */
    void readOption(T)(string names, T* value, string helpText, bool required = false, string propertyPath = null)
    {
        Option opt = splitAndGet(names);
        opt.help = helpText;
        opt.required = required;
        options ~= opt;

        try
        {
            GetoptResult gr;
            if (required)
                gr = getopt(args, getoptRequireConfig, names, helpText, value);
            else
                gr = getopt(args, getoptConfig, names, helpText, value);

            if (!helpWanted)
                helpWanted = gr.helpWanted;

            string propName = (propertyPath is null) ? "args." ~ opt.optLong[2..$] : propertyPath;
            addProperties!T(propName, (*value));
        }
        catch (Exception e)
            errorWanted = true;
    }

    /**
     * Проверка на успешность разбора командной строки
     */
    bool checkOptions()
    {
        return !(helpWanted || errorWanted);
    }

    /**
     * Вывод справки в поток стандартного вывода
     *
     * Params:
     *
     * text = Заголовок сообщения
     */
    void printer(string text)
    {
        defaultGetoptPrinter(text, options);
    }

    /**
     * Возвращает свойства полученные при разборе
     */
    Config getOptionConfig()
    {
        return config;
    }

    /**
     * Возвращает свойства полученные из переменных окружения приложения
     */
    Config getEnvironmentConfig()
    {
        Config[string] map;
        foreach(string key, string val; environment.toAA)
            map[key] = Config(val);

        return Config(["env": Config(map)]);
    }
}

