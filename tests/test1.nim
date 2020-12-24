#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import json
import streams
import strutils
import unittest

import tal_pagetemplate

type
  Vars = ref object of RootObj
    repeat_src: seq[int]


proc parse_all(fp: Stream): string =  # {{{1
    # var vars = Vars(repeat_src: @[1, 2, 3, 4, 5])
    var vars = newJObject()
    vars.add("repeat_src", % @[1, 2, 3, 4, 5])
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


test "T2-3-1: can parse tal:omit-tag":  # {{{1
    var fp = newStringStream("<a tal:omit-tag=\"\">this</a>")
    check parse_all(fp) == ""


test "T2-3-2: can parse tal:omit-tag 2 - nested":  # {{{1
    var fp = newStringStream("<a tal:omit-tag=\"\">this<b></b></a>")
    check parse_all(fp) == ""

    fp = newStringStream("<a tal:omit-tag=\"\">this<b></b><c a=\"2\"></c></a>")
    check parse_all(fp) == ""


test "T2-4-1: can parse tal:repeat":  # {{{1
    var fp = newStringStream("<a tal:repeat=\"i repeat_src\" " &
                             "tal:content=\"repeat/i/number\">this</a>")
    check parse_all(fp) == "<a>1</a><a>2</a><a>3</a><a>4</a><a>5</a>"


test "T2-4-2: can parse tal:repeat 2 - mix contents":  # {{{1
    var fp = newStringStream("""
        <a tal:repeat="  i   repeat_src   ">
        <b tal:content="repeat/i/number"></b>this</a>""".strip())
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
    var fp = newStringStream("<a tal:define=\"j 2\">define bb:</a>" &
                             "<bb tal:content=\"j\">is number ?</bb>")
    check parse_all(fp) == "<a>define bb:</a><bb>2</bb>"


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
