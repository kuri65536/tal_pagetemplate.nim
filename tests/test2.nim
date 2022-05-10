#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import json
import os
import streams
import system
import typeinfo
import unittest

import tal_pagetemplate
import tal_pagetemplate/tal_i18n


proc parse_all(fp: Stream): string =  # {{{1
    var path = joinPath(parentDir(currentSourcePath), "catalog")
    setup_i18n("en", "utf-8", "test", path)

    var vars = newJObject()
    # for test: 3-1-1
    vars.add("this", %"Becon")
    vars.add("that", %"Sesami")

    # for test: 3-1-2, 3-2-1
    var (tmp1, tmp2) = (newJObject(), newJObject())
    tmp2.add("total", %5)
    tmp2.add("number", %1)
    tmp1.add("form", tmp2)
    vars.add("request", tmp1)

    # for test: 3-1-3
    vars.add("cost", %42.0)

    # for test: 3-3-1
    tmp1 = newJObject()
    tmp1.add("objectIds", % @["1", "2", "3"])
    vars.add("context", tmp1)
    vars.add("empty_sequence", % @[])

    var fn = parse_template(fp, "", vars)
    var ret = ""
    while not finished(fn):
        ret &= fn()
    return ret


proc parse_all2(fp: Stream, vars: Any): string =  # {{{1
    var path = joinPath(parentDir(currentSourcePath), "catalog")
    setup_i18n("en", "utf-8", "test", path)

    var fn = parse_template(fp, "", vars)
    var ret = ""
    while not finished(fn):
        ret &= fn()
    return ret


test "T3-1-1: can parse string - from reference - basic":  # {{{1
    var fp = newStringStream("<span tal:replace=\"string:$this and $that\">" &
                             "  Spam and Eggs</span>")
    check parse_all(fp) == "Becon and Sesami"


test "T3-1-2: can parse string - from reference 2 - using paths":  # {{{1
    var fp = newStringStream("<p tal:content=\"string:total: " &
                             "${request/form/total}\">  total: 1</p>")
    check parse_all(fp) == "<p>total: 5</p>"


test "T3-1-3: can parse string - from reference 3 - including dollar":  # {{{1
    var fp = newStringStream("<p tal:content=\"string:cost: $$$cost\">" &
                             "  cost: $42.00</p>")
    check parse_all(fp) == "<p>cost: $42.0</p>"


test "T3-2-1: can parse exists - from reference":  # {{{1
    var fp = newStringStream("<p tal:condition=\"" &
                             "not:exists:request/form/number\">" &
                             "  Please enter a number between 0 and 5</p>")
    check parse_all(fp) == ""

    fp = newStringStream("<p tal:condition=\"" &
                         "exists:request/form/number\">" &
                         "  Please enter a number between 0 and 5</p>")
    check parse_all(fp) == "<p>  Please enter a number between 0 and 5</p>"


test "T3-3-1: can parse not - from reference - testing sequences":  # {{{1
    var fp = newStringStream("<p tal:condition=\"" &
                             "not:context/objectIds\">" &
                             "  There are no contained objects</p>")
    check parse_all(fp) == ""

    fp = newStringStream("<p tal:condition=\"" &
                         "context/objectIds\">" &
                         "  There are no contained objects</p>")
    check parse_all(fp) == "<p>  There are no contained objects</p>"

    fp = newStringStream("<p tal:condition=\"" &
                             "empty_sequence\">" &
                             "  There are no contained objects</p>")
    check parse_all(fp) == ""


type
  TestObj1 = object
    n: int
    n8: int8
    n16: int16
    n32: int32
    n64: int64
    u: uint
    u8: uint8
    u16: uint16
    u32: uint32
    u64: uint64


test "T4-1-1: use nim rtti - n, n8-64":  # {{{1
    var tmp = TestObj1(n: 5, n8: 10, n16: 15, n32: 20, n64: 25)
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:content=\"n\">1</p>" &
                             "<p tal:content=\"n8\">2</p>" &
                             "<p tal:content=\"n16\">3</p>" &
                             "<p tal:content=\"n32\">4</p>" &
                             "<p tal:content=\"n64\">5</p>")
    check parse_all2(fp, v) == "<p>5</p><p>10</p><p>15</p><p>20</p><p>25</p>"


test "T4-1-2: use nim rtti - u, u8-64":  # {{{1
    var tmp = TestObj1(u: 3, u8: 6, u16: 9, u32: 12, u64: 15)
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:content=\"u\">1</p>" &
                             "<p tal:content=\"u8\">2</p>" &
                             "<p tal:content=\"u16\">3</p>" &
                             "<p tal:content=\"u32\">4</p>" &
                             "<p tal:content=\"u64\">5</p>")
    check parse_all2(fp, v) == "<p>3</p><p>6</p><p>9</p><p>12</p><p>15</p>"


type
  TestObj2 = object
    f: float
    f32: float32
    f64: float64
    ch: char
    str: string
    b: bool


test "T4-1-3: use nim rtti - f, f32-64":  # {{{1
    var tmp = TestObj2(f: 1.0, f32: 2.0, f64: 3.0)
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"f\"> </p>," &
                             "<p tal:replace=\"f32\"> </p>," &
                             "<p tal:replace=\"f64\"> </p>,")
    check parse_all2(fp, v) == "1.0,2.0,3.0,"


test "T4-1-4: use nim rtti - ch, string, bool":  # {{{1
    var tmp = TestObj2(ch: 'E', str: "test4-1-4", b: true)
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"ch\"> </p>," &
                             "<p tal:replace=\"str\"> </p>," &
                             "<p tal:replace=\"b\"> </p>,")
    check parse_all2(fp, v) == "E,test4-1-4,true,"


type
  TestObj3 = object
    ns: set[char]
    fs: seq[float]
    ss: array[2, string]
    sub: TestObj2

  TestObj4 = object
    o2: TestObj2
    o3: TestObj3

  TestObj5 = object
    o1: TestObj1
    o4: TestObj4

  test_enum_t = enum
    a, b, c

  TestObj6 = object
    en: test_enum_t


test "T4-1-5: use nim rtti - set, seq, array":  # {{{1
    var tmp = TestObj3(ns: {'F'..'H'},
                       fs: @[1.0, 2.0],
                       ss: ["a", "b"])
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"ns\"> </p>-" &
                             "<p tal:replace=\"fs\"> </p>-" &
                             "<p tal:replace=\"ss\"> </p>-")
    check parse_all2(fp, v) == "{70, 71, 72}-[1.0, 2.0]-(\"a\", \"b\")-"
    # can't serialize set[any] from integer
    # check parse_all2(fp, v) == "{'F', 'G', 'H'}-[1.0, 2.0]-(\"a\", \"b\")-"


test "T4-1-6: use nim rtti - enum":  # {{{1
    var tmp = TestObj6(en: test_enum_t.b)
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "enum:${en}\"></p>")
    check parse_all2(fp, v) == "enum:b"


test "T4-2-1: use nim rtti - w/repeat, set":  # {{{1
    var tmp = TestObj3(ns: {'F'..'H'},
                       fs: @[], ss: ["a", "b"])
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:repeat=\"i ns\" tal:content=\"i\"></p>")
    check parse_all2(fp, v) == "<p>70</p><p>71</p><p>72</p>"


test "T4-2-2: use nim rtti - w/repeat, seq":  # {{{1
    var tmp = TestObj3(ns: {'F'..'H'},
                       fs: @[0.1, 0.2, 0.3], ss: ["a", "b"])
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:repeat=\"i fs\" tal:content=\"i\"></p>")
    check parse_all2(fp, v) == "<p>0.1</p><p>0.2</p><p>0.3</p>"


test "T4-2-3: use nim rtti - w/repeat, array":  # {{{1
    var tmp = TestObj3(ns: {'F'..'H'},
                       fs: @[0.1, 0.2, 0.3], ss: ["a", "b"])
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:repeat=\"i ss\" tal:content=\"i\"></p>")
    check parse_all2(fp, v) == "<p>a</p><p>b</p>"


test "T4-3-1: use nim rtti - w/string expressions":  # {{{1
    var tmp = TestObj3(ns: {'F'..'H'},
                       fs: @[0.9, 1.0, 1.1], ss: ["a", "b"])
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "set:${ns}, list:${fs}, array:${ss}\"></p>")
    check parse_all2(fp, v) == "set:{70, 71, 72}, list:[0.9, 1.0, 1.1], " &
                               "array:(\"a\", \"b\")"


test "T4-4-1: use nim rtti - w/object - depth 1":  # {{{1
    var tmp = TestObj3(sub: TestObj2(ch: 'E', str: "test4-4-1", b: true),
                       fs: @[0.9, 1.0, 1.1], ss: ["a", "b"])
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "obj-ch:${sub/ch} obj-str:${sub/str}" &
                             " obj-b:${sub/b}\"></p>")
    check parse_all2(fp, v) == "obj-ch:'E' obj-str:\"test4-4-1\" obj-b:true"


test "T4-4-2: use nim rtti - w/object - depth 2":  # {{{1
    var tmp = TestObj4(o2: TestObj2(),
                       o3: TestObj3(sub: TestObj2(ch: 'A')))
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "o3-o2-ch:${o3/sub/ch}\"></p>")
    check parse_all2(fp, v) == "o3-o2-ch:'A'"


test "T4-4-3: use nim rtti - w/object - depth 3":  # {{{1
    var tmp = TestObj5(o4: TestObj4(o3: TestObj3(sub: TestObj2(
                       ch: 'B'))))
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "o4-o3-o2-ch:${o4/o3/sub/ch}\"></p>")
    check parse_all2(fp, v) == "o4-o3-o2-ch:'B'"


test "T4-5-1: use nim rtti - w/object - various types of properties":  # {{{1
    # char, string, boolean already tested in 4-4-1
    var tmp = TestObj4(o3: TestObj3(
                       ns: {'O'..'P'}, ss: ["a", "b"],
                       fs: @[10.3, 11.5, 12.7]))
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "ns:${o3/ns} fs:${o3/fs} ss:${o3/ss}\"></p>")
    check parse_all2(fp, v) == ("ns:{79, 80} fs:[10.3, 11.5, 12.7] " &
                                "ss:(\"a\", \"b\")")


test "T4-6-1: use nim rtti - invalid expressions":  # {{{1
    var tmp = TestObj3(ns: {'F'..'H'},
                       fs: @[0.9, 1.0, 1.1], ss: ["a", "b"])
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "no-exist:${invalid}\"></p>")
    check parse_all2(fp, v) == "no-exist:"


test "T4-6-2: use nim rtti - invalid properties":  # {{{1
    var tmp = TestObj3(ns: {'F'..'H'},
                       fs: @[0.9, 1.0, 1.1], ss: ["a", "b"],
                       sub: TestObj2())
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"string:" &
                             "exist:${sub/b}, no-exist:${sub/c}\"></p>")
    check parse_all2(fp, v) == "exist:false, no-exist:"


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
