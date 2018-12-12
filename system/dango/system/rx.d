/**
 * Модуль фасад над библиотекой Rx
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-12-12
 */

module dango.system.rx;

// TODO: есть проблема в использовании scheduler из библиотеки rx
//      поэтому импортируем все кроме scheduler
public
{
    import rx.observable : Observable, doSubscribe;
    import rx.disposable : Disposable;
    import rx.observer : Observer;
    import rx.subject : SubjectObject;
}

