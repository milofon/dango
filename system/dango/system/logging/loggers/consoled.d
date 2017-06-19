/**
 * Модуль консольного логера, основанного на vibe.core.log и consoled
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Authors: Maksim Galanin
 */
module dango.system.logging.loggers.consoled;

private
{
    import std.typecons: Tuple, tuple;
    import std.stdio: writeln, write, writef;

    import vibe.core.log;
    import consoled: Color, resetColors, foreground, background;
    import proped: Properties;

    import dango.system.logging.core;
}

/**
 * Фабрика создающая расширенный консольный логгер
 */
class ConsoledLoggerFactory : LoggerFactory
{
    shared(Logger) createLogger(Properties config)
    {
        LogLevel level = matchLogLevel(config.getOrElse("level", "info"));

        auto result = cast(shared)new ConsoledLogger(level);
        return result;
    }
}


/**
 * Расширенный консольный логгер, с возможностью управления цветом
 */
class ConsoledLogger : Logger
{
    alias ColorTheme = Tuple!(Color, Color);

    enum themes = [
        LogLevel.trace: ColorTheme(Color.cyan, Color.initial),
        LogLevel.debugV: ColorTheme(Color.green, Color.initial),
        LogLevel.debug_: ColorTheme(Color.green, Color.initial),
        LogLevel.diagnostic: ColorTheme(Color.green, Color.initial),
        LogLevel.info: ColorTheme(Color.initial, Color.initial),
        LogLevel.warn: ColorTheme(Color.yellow, Color.initial),
        LogLevel.error: ColorTheme(Color.red, Color.initial),
        LogLevel.critical: ColorTheme(Color.white, Color.red),
        LogLevel.fatal: ColorTheme(Color.white, Color.red),
        LogLevel.none: ColorTheme(Color.initial, Color.initial),
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
        static if (is(typeof(tm.fracSecs))) auto msecs = tm.fracSecs.total!"msecs"; // 2.069 has deprecated "fracSec"
        else auto msecs = tm.fracSec.msecs;

        writef("[%08X:%08X %d.%02d.%02d %02d:%02d:%02d.%03d ",
                msg.threadID, msg.fiberID,
                tm.year, tm.month, tm.day, tm.hour, tm.minute, tm.second, msecs);
        foreground = theme[0];
        background = theme[1];
        write(pref);
        resetColors();
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

