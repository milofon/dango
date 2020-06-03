/**
 * Модуль консольного логера, основанного на vibe.core.log и termcolor
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-18
 */

module dango.system.logging.loggers.console;

private
{
    import std.typecons: Tuple;
    import std.stdio: stdout, stderr, File;
    import std.format : fmt = format;

    import vibe.core.log : Logger, LogLevel, LogLine;
    import termcolor : AnsiColor = C, fg, bg, resetColor;

    import dango.system.logging.core;
}


/**
 * Фабрика создающая расширенный консольный логгер
 */
class ConsoleLoggerFactory : LoggerFactory
{
    shared(Logger) createComponent(UniConf config) @trusted
    {
        LogLevel level = matchLogLevel(config.getOrElse("level", "info"));
        bool isSync = config.getOrElse("sync", false);
        string outStreamName = config.getOrElse("outStream", "stdout");
        return cast(shared)new ConsoleLogger(level, outStreamName, isSync);
    }
}


/**
 * Расширенный консольный логгер, с возможностью управления цветом
 */
class ConsoleLogger : Logger
{
    private 
    {
        immutable bool isSync;
        File outStream;
    }


    this(LogLevel level, string outStreamName, bool isSync) @trusted
    {
        this.isSync = isSync;
        if (outStreamName == "stderr")
            this.outStream = stderr;
        else
            this.outStream = stdout;
        minLevel = level;
    }

    alias ColorTheme = Tuple!(AnsiColor, AnsiColor);

    enum themes = [
        LogLevel.trace: ColorTheme(AnsiColor.cyan, AnsiColor.reset),
        LogLevel.debugV: ColorTheme(AnsiColor.green, AnsiColor.reset),
        LogLevel.debug_: ColorTheme(AnsiColor.green, AnsiColor.reset),
        LogLevel.diagnostic: ColorTheme(AnsiColor.green, AnsiColor.reset),
        LogLevel.info: ColorTheme(AnsiColor.reset, AnsiColor.reset),
        LogLevel.warn: ColorTheme(AnsiColor.yellow, AnsiColor.reset),
        LogLevel.error: ColorTheme(AnsiColor.red, AnsiColor.reset),
        LogLevel.critical: ColorTheme(AnsiColor.white, AnsiColor.red),
        LogLevel.fatal: ColorTheme(AnsiColor.white, AnsiColor.red),
        LogLevel.none: ColorTheme(AnsiColor.reset, AnsiColor.reset),
    ];

    override void beginLine(ref LogLine msg) @trusted
    {
        string pref;
        final switch (msg.level)
        {
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

        outStream.writef("[%08X:%08X %d.%02d.%02d %02d:%02d:%02d.%03d ",
                msg.threadID, msg.fiberID,
                tm.year, tm.month, tm.day, tm.hour, tm.minute, tm.second, msecs);
        outStream.write(theme[0].fg, theme[1].bg, pref, resetColor);
        outStream.write("] ");
    }

    override void put(scope const(char)[] text)
    {
        outStream.write(text);
    }

    override void endLine() @trusted
    {
        outStream.writeln();
        if (isSync)
            outStream.flush();
    }
}

