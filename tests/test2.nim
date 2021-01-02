#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import json
import ospaths
import streams
import strutils
import system
import unittest

import tal_pagetemplate
import tal_pagetemplate/tal_i18n


type
  Vars = ref object of RootObj
    repeat_src: seq[int]


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


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
