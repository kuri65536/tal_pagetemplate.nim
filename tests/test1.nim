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


test "T2-4-2: can parse tal:repeat 2 - various parameters":  # {{{1
    var fp = newStringStream("<a tal:repeat=\"  i   repeat_src   \" " &
                             "tal:content=\"repeat/i/number\">this</a>")
    check parse_all(fp) == "<a>1</a><a>2</a><a>3</a><a>4</a><a>5</a>"


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
