/**
 * Модуль фабрики по созданию компонентов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-01
 */

module dango.service.factory;

private
{
    import std.string : outdent;
    import std.format : fmt = format;
    import std.uni : toUpper;

    import poodinis : DependencyContainer, autowire;
}


/**
 * Фабрика компонент с кастомными конструкторами
 */
template ComponentFactory(Components...)
{
    class Wrapper(T)
    {
        /**
         * Возвращает новый экземпляр компонента по имени
         * Params:
         * name = Имя компонента
         * args = Аргументы конструктора
         */
        T create(string F = __FILE__, size_t L = __LINE__, A...)(string name, A args)
        {
            enum SWITH = GenerateSwith!(Components.length, "return new R(args);");
            // pragma (msg, SWITH);

            switch (name.toUpper)
            {
                mixin(SWITH);
                default:
                    return null;
            }
        }

        /**
         * Возвращает новый экземпляр компонента по имени
         * Дополнительно производит разрешение зависимостей
         * Params:
         * name = Имя компонента
         * args = Аргументы конструктора
         */
        T resolve(string F = __FILE__, size_t L = __LINE__, A...)
            (shared(DependencyContainer) container, string name, A args)
        {
            enum SWITH = GenerateSwith!(Components.length, q{
                R ret = new R(args);
                container.autowire(ret);
                return ret;
            });
            // pragma (msg, SWITH);

            switch (name.toUpper)
            {
                mixin(SWITH);
                default:
                    return null;
            }
        }
    }


private:


    template GenerateSwith(int I, string E)
    {
        static if (I > 0)
        {
            enum GenerateSwith = fmt!q{
                case Components[%s]:
                {
                    alias R = Components[%s];
                    static if (__traits(compiles, new R(args)))
                    {
                        %s
                    }
                    else
                        throw new Exception("The constructor '" ~ R.stringof
                                ~ "' does not support the specified set of arguments",
                                F, L);
                }
            }(I-2, I-1, E).outdent ~ GenerateSwith!(I - 2, E);
        }
        else
            enum GenerateSwith = "";
    }
}

