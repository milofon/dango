/**
 * Contains functionality for autowiring dependencies using a dependency container.
 *
 * Copyright: (c) 2015-2020, Milofon Project.
 * License: Subject to the terms of the BSD 3-Clause License, as written in the included LICENSE.md file.
 * Author: <m.galanin@milofon.pro> Maksim Galanin
 * Date: 2020-04-16
 */

module dango.inject.injection;

private
{
    import std.traits;

    import dango.inject.container;
}


struct Inject(QualifierType) {}


struct Named
{
    string name;
}


void inject(Type)(DependencyContainer container, Type instance) @safe
{
    static if (BaseClassesTuple!Type.length > 1)
        inject!(BaseClassesTuple!Type[0])(container, instance);

    static foreach (name; FieldNameTuple!Type)
        injectMember!(name, Type)(container, instance);
}

version (unittest)
{
    interface Printer { string title() @safe; }
    class LaserPrinter : Printer {
        private string _title;
        @Inject
        this(@Named("printer") string title) { _title = title; }
        string title() @safe { return _title; }
    }
    interface Report {}
    abstract class SimpleReport : Report {
        @Inject!LaserPrinter 
        private Printer _printer;
        @Inject @Named("pages")
        private int _pages;
        @Inject @Named("report")
        private string _title;
        @Inject
        private ubyte[] _code;
        @Inject
        private Printer _printer2 = new LaserPrinter("superlaser");
    }
    class AdditionalReport : SimpleReport {}
}

@("Should work inject to object")
@safe unittest
{
    auto cont = new DependencyContainer();
    cont.register!(Printer, LaserPrinter);  
    cont.value!int("pages", 2);
    cont.value!string("printer", "laser");
    cont.value!string("report", "matrix");
    cont.value!string("other");
    cont.value!ubyte(1);
    cont.value!ubyte(2);
    cont.register!(Report, AdditionalReport);
    auto rep = cast(SimpleReport)cont.resolve!Report();
    assert (rep);
    assert (rep._printer2.title == "superlaser");
    assert (rep._printer && rep._printer.title == "laser");
    assert (rep._title == "matrix");
    assert (rep._code == [1, 2]);
}


private:


void injectMember(string name, Type)(DependencyContainer container, Type instance) @safe
{
    alias member = __traits(getMember, Type, name);
    static foreach (attribute; __traits(getAttributes, member))
    {
        static if (is(attribute == Inject!T, T : typeof(member)))
            injectMemberType!(name, Type, typeof(member), T)(container, instance);
        else static if (__traits(isSame, attribute, Inject))
            injectMemberType!(name, Type, typeof(member))(container, instance);
    }
}


void injectMemberType(string name, Type, MemberTypes...)(DependencyContainer container, Type instance) @safe
{
    alias MemberType = MemberTypes[0];
    static if (is(MemberType == class) || is(MemberType == interface))
        if (__traits(getMember, instance, name) !is null)
            return;

    static if (isDynamicArray!MemberType && !isSomeString!MemberType)
        injectMultiple!(name, Type, MemberTypes)(container, instance);
    else
        injectSingle!(name, Type, MemberTypes)(container, instance);
}


void injectMultiple(string name, Type, MemberTypes...)(DependencyContainer container, Type instance) @safe
{
    alias MemberElementType = ForeachType!(MemberTypes[0]);
    enum namedUDAs = getUDAs!(__traits(getMember, Type, name), Named);
    static if (namedUDAs.length)
        __traits(getMember, instance, name) = container.resolveAll!(MemberElementType)(namedUDAs[0].name);
    else
        __traits(getMember, instance, name) = container.resolveAll!(MemberElementType)();
}


void injectSingle(string name, Type, MemberTypes...)(DependencyContainer container, Type instance) @safe
{
    enum namedUDAs = getUDAs!(__traits(getMember, Type, name), Named);
    static if (namedUDAs.length)
        __traits(getMember, instance, name) = container.resolve!(MemberTypes)(namedUDAs[0].name);
    else
    {
        auto ins = container.resolve!(MemberTypes)();
        assert (ins);
        __traits(getMember, instance, name) = container.resolve!(MemberTypes)();
    }
}

