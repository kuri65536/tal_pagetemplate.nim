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
import strutils
import system
import unittest

import tal_pagetemplate
import tal_pagetemplate/tal_i18n


#[
type
  Vars = ref object of RootObj
    repeat_src: seq[int]
]#


proc parse_all(fp: Stream): string =  # {{{1
    var path = joinPath(parentDir(currentSourcePath), "catalog")
    setup_i18n("en", "utf-8", "another", path)
    setup_i18n("en", "utf-8", "test", path)

    var vars = newJObject()
    vars.add("repeat_src", % @[1, 2, 3, 4, 5])
    var subobj = newJObject()
    subobj.add("getUserName", %"shimoda <kuri65536@hotmail.com>")
    vars.add("user", subobj)
    subobj = newJObject()
    subobj.add("getStory", %"this is <em>markup'ed</em> content")
    vars.add("context", subobj)
    var fn = parse_template(fp, "", vars)
    var ret = ""
    while not finished(fn):
        ret &= fn()
    return ret


test "T1-1-1: can parse normal xml":  # {{{1
    # check hierarch outputs
    var fp = newStringStream("<a>this</a>")
    check parse_all(fp) == "<a>this</a>"

    fp = newStringStream("<a><b>this</b></a>")
    check parse_all(fp) == "<a><b>this</b></a>"

    fp = newStringStream("<a><b><c>this</c></b></a>")
    check parse_all(fp) == "<a><b><c>this</c></b></a>"

    # check attrs
    fp = newStringStream("<a b=\"1\">this</a>")
    check parse_all(fp) == "<a b=\"1\">this</a>"


test "T2-1-1: can parse tal:replace":  # {{{1
    var fp = newStringStream("<a tal:replace=\"1\">this</a>")
    check parse_all(fp) == "1"


test "T2-2-1: can parse tal:content":  # {{{1
    var fp = newStringStream("<a tal:content=\"1\">this</a>")
    check parse_all(fp) == "<a>1</a>"


test "T2-2-2: can parse tal:content - from reference":  # {{{1
    var fp = newStringStream("<p tal:content=\"user/getUserName\">" &
                             "Fred Farkas</p>")
    check parse_all(fp) == "<p>shimoda &lt;kuri65536@hotmail.com&gt;</p>"


test "T2-2-3: can parse tal:content - from reference 2":  # {{{1
    var fp = newStringStream("<p tal:content=\"structure context/getStory\">" &
                             "  marked <b>up</b> content go here.</p>")
    check parse_all(fp) == "<p>this is <em>markup'ed</em> content</p>"


test "T2-3-1: can parse tal:omit-tag":  # {{{1
    var fp = newStringStream("<a tal:omit-tag=\"\">this</a>")
    check parse_all(fp) == "this"


test "T2-3-2: can parse tal:omit-tag 2 - nested":  # {{{1
    var fp = newStringStream("<a tal:omit-tag=\"\">this<b></b></a>")
    check parse_all(fp) == "this<b></b>"

    fp = newStringStream("<a tal:omit-tag=\"\">this<b></b><c a=\"2\"></c></a>")
    check parse_all(fp) == "this<b></b><c a=\"2\"></c>"


test "T2-3-3: can parse tal:omit-tag 3 - from reference":  # {{{1
    var fp = newStringStream("<div tal:omit-tag=\"\" comment=\"t\">" &
                             "<i>...but this text will remain.</i></div>")
    check parse_all(fp) == "<i>...but this text will remain.</i>"


test "T2-3-4: can parse tal:omit-tag 4 - from reference 2":  # {{{1
    var fp = newStringStream("<b tal:omit-tag=\"not:bold\">" &
                             "  I may be bold.</b>")
    check parse_all(fp) == "<b>  I may be bold.</b>"

    fp = newStringStream("<a tal:define=\"bold 1\">" &
                         "<b tal:omit-tag=\"not:bold\">" &
                         "  I may be bold.</b></a>")
    check parse_all(fp) == "<a>  I may be bold.</a>"


test "T2-3-5: can parse tal:omit-tag 4 - from reference 3":  # {{{1
    var fp = newStringStream("<span tal:repeat=\"n repeat_src\"" &
                             "      tal:omit-tag=\"\">" &
                             "<p tal:content=\"n\">1</p></span>")
    check parse_all(fp) == "<p>1</p><p>2</p><p>3</p><p>4</p><p>5</p>"


test "T2-4-1: can parse tal:repeat":  # {{{1
    var fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                             "tal:content=\"repeat/i/number\">this</a>")
    check parse_all(fp) == "<a>1</a><a>2</a><a>3</a><a>4</a><a>5</a>"


test "T2-4-2: can parse tal:repeat 2 - mix contents":  # {{{1
    var fp = newStringStream(
        "<a tal:repeat=\"  i   repeat_src   \">" &
        "<b tal:content=\"repeat/i/number\"></b>this</a>")
    var answer = """<a><b>1</b>this</a>
                    <a><b>2</b>this</a>
                    <a><b>3</b>this</a>
                    <a><b>4</b>this</a>
                    <a><b>5</b>this</a>""".replace(" ", "").replace("\n", "")
    check parse_all(fp) == answer


test "T2-4-3: can parse tal:repeat 3 - various parameters":  # {{{1
    var fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                             "tal:content=\"repeat/i/number\">this</a>")
    check parse_all(fp) == "<a>1</a><a>2</a><a>3</a><a>4</a><a>5</a>"

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/index\">this</a>")
    check parse_all(fp) == "<a>0</a><a>1</a><a>2</a><a>3</a><a>4</a>"

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/odd\">this</a>")
    check parse_all(fp) == "<a>0</a><a>1</a><a>0</a><a>1</a><a>0</a>".replace(
                            "0", "false").replace("1", "true")

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/even\">this</a>")
    check parse_all(fp) == "<a>0</a><a>1</a><a>0</a><a>1</a><a>0</a>".replace(
                            "0", "true").replace("1", "false")

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/letter\">this</a>")
    check parse_all(fp) == "<a>a</a><a>b</a><a>c</a><a>d</a><a>e</a>"

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/Letter\">this</a>")
    check parse_all(fp) == "<a>A</a><a>B</a><a>C</a><a>D</a><a>E</a>"

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/roman\">this</a>")
    check parse_all(fp) == "<a>i</a><a>ii</a><a>iii</a><a>iv</a><a>v</a>"

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/Roman\">this</a>")
    check parse_all(fp) == "<a>I</a><a>II</a><a>III</a><a>IV</a><a>V</a>"

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/start\">this</a>")
    check parse_all(fp) == "<a>1</a><a>0</a><a>0</a><a>0</a><a>0</a>".replace(
                            "1", "true").replace("0", "false")

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/end\">this</a>")
    check parse_all(fp) == "<a>0</a><a>0</a><a>0</a><a>0</a><a>1</a>".replace(
                            "1", "true").replace("0", "false")

    fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                         "tal:content=\"repeat/i/length\">this</a>")
    check parse_all(fp) == "<a>5</a><a>5</a><a>5</a><a>5</a><a>5</a>"


test "T2-5-1: can parse tal:define":  # {{{1
    var fp = newStringStream("<a tal:define=\"global j 2\">define bb:</a>" &
                             "<bb tal:content=\"j\">is number ?</bb>")
    check parse_all(fp) == "<a>define bb:</a><bb>2</bb>"

    fp = newStringStream("<a tal:define=\"global j 2; global  k 3  \">define bb:</a>" &
                         "<bb tal:content=\"j\">is number ?</bb>" &
                         "<cc tal:content=\"k\">is number ?</cc>")
    check parse_all(fp) == "<a>define bb:</a><bb>2</bb><cc>3</cc>"


test "T2-5-2: can parse tal:define, local and global":  # {{{1
    var fp = newStringStream("<a tal:define=\"j 2\">lcl or glb</a>" &
                             "<bar tal:define=\"global k 3;local m 4\">" &
                             "<car tal:replace=\"j\"></car>" &
                             "<car tal:replace=\"k\"></car>" &
                             "<car tal:replace=\"m\"></car>" &
                             "</bar><demo>" &
                             "<car tal:replace=\"j\"></car>" &
                             "<car tal:replace=\"k\"></car>" &
                             "<car tal:replace=\"m\"></car>" &
                             "</demo>")
    check parse_all(fp) == "<a>lcl or glb</a><bar>null34</bar>" &
                           "<demo>null3null</demo>"


test "T2-6-1: can parse tal:attribute, simple and override":  # {{{1
    var fp = newStringStream("<lv1 tal:define=\"i 10; j 20\" st=\"1\">" &
                             "<lv2 tal:attributes=\"st j; hp i\"" &
                             " st=\"2\">next</lv2></lv1>")
    check parse_all(fp) == "<lv1 st=\"1\"><lv2 st=\"20\" hp=\"10\">" &
                           "next</lv2></lv1>"



test "T2-7-1: can parse i18n:translate":  # {{{1
    var fp = newStringStream("<test i18n:translate=\"1\">uno</test>")
    check parse_all(fp) == "<test>one</test>"


test "T2-8-1: can parse i18n:domain":  # {{{1
    var fp = newStringStream("<test i18n:translate=\"2\">bel</test>" &
                             "<anot i18n:domain=\"another\"" &
                             " i18n:translate=\"2\">bel</anot>" &
                             "<test2 i18n:translate=\"1\">uno</test2>")
    check parse_all(fp) == "<test>two</test><anot>ni</anot><test2>one</test2>"


test "T2-9-1: can parse tal:condition":  # {{{1
    var fp = newStringStream("<div tal:condition=\"1\">1</div>" &
                             "<div tal:condition=\"0\">2</div>")
    check parse_all(fp) == "<div>1</div>"


test "T2-10-1: can parse i18n:attributes":  # {{{1
    var fp = newStringStream("<test i18n:translate=\"2\">bel</test>" &
                             "<anot i18n:domain=\"another\"" &
                             " i18n:attributes=\"attr 2\">bel</anot>" &
                             "<test2 i18n:attributes=\"a 1;b 2\">uno</test2>")
    check parse_all(fp) == "<test>two</test><anot attr=\"ni\">bel</anot>" &
                           "<test2 a=\"one\" b=\"two\">uno</test2>"


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
