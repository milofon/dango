/**
 * Модуль консольного логера, основанного на vibe.core.log и consoled
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.logging.loggers.console;

private
{
    import std.typecons: Tuple, tuple;
    import std.stdio: writeln, write, writef;

    import vibe.core.log;
    import proped: Properties;

    import dango.system.logging.core;
}


enum AnsiColor
{
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    defaultColor = 39
}


struct StringWithBoth(T)
{
    string s;
    T fg;
    T bg;
    this(string s, T fg, T bg)
    {
        this.s = s;
        this.fg = fg;
        this.bg = bg;
    }

    string toString()
    {
        return "\033[%dm\033[%dm%s\033[0m".format(fg, bg + 10, s);
    }
}


/**
 * Фабрика создающая расширенный консольный логгер
 */
class ConsoleLoggerFactory : LoggerFactory
{
    shared(Logger) createLogger(Properties config)
    {
        LogLevel level = matchLogLevel(config.getOrElse("level", "info"));

        auto result = cast(shared)new ConsoleLogger(level);
        return result;
    }
}


/**
 * Расширенный консольный логгер, с возможностью управления цветом
 */
class ConsoleLogger : Logger
{
    alias ColorTheme = Tuple!(AnsiColor, AnsiColor);

    enum themes = [
        LogLevel.trace: ColorTheme(AnsiColor.cyan, AnsiColor.defaultColor),
        LogLevel.debugV: ColorTheme(AnsiColor.green, AnsiColor.defaultColor),
        LogLevel.debug_: ColorTheme(AnsiColor.green, AnsiColor.defaultColor),
        LogLevel.diagnostic: ColorTheme(AnsiColor.green, AnsiColor.defaultColor),
        LogLevel.info: ColorTheme(AnsiColor.defaultColor, AnsiColor.defaultColor),
        LogLevel.warn: ColorTheme(AnsiColor.yellow, AnsiColor.defaultColor),
        LogLevel.error: ColorTheme(AnsiColor.red, AnsiColor.defaultColor),
        LogLevel.critical: ColorTheme(AnsiColor.white, AnsiColor.red),
        LogLevel.fatal: ColorTheme(AnsiColor.white, AnsiColor.red),
        LogLevel.none: ColorTheme(AnsiColor.defaultColor, AnsiColor.defaultColor),
    ];

    this(LogLevel level) {
        minLevel = level;
    }

    override void beginLine(ref LogLine msg) @trusted
    {
        string pref;
        final switch (msg.level) {
            case LogLevel.trace: pref = "trc"; break;
            case LogLevel.debugV: pref = "dbv"; break;
            case LogLevel.debug_: pref = "dbg"; break;
            case LogLevel.diagnostic: pref = "dia"; break;
            case LogLevel.info: pref = "INF"; break;
            case LogLevel.warn: pref = "WRN"; break;
            case LogLevel.error: pref = "ERR"; break;
            case LogLevel.critical: pref = "CRITICAL"; break;
            case LogLevel.fatal: pref = "FATAL"; break;
            case LogLevel.none: assert(false);
        }
        ColorTheme theme = themes[msg.level];
        auto tm = msg.time;
        static if (is(typeof(tm.fracSecs)))
            auto msecs = tm.fracSecs.total!"msecs";
        else auto msecs = tm.fracSec.msecs;

        writef("[%08X:%08X %d.%02d.%02d %02d:%02d:%02d.%03d ",
                msg.threadID, msg.fiberID,
                tm.year, tm.month, tm.day, tm.hour, tm.minute, tm.second, msecs);

        write(StringWithBoth!AnsiColor(pref, theme[0], theme[1]));
        write("] ");
    }

    override void put(scope const(char)[] text)
    {
        write(text);
    }

    override void endLine()
    {
        writeln();
    }
}

