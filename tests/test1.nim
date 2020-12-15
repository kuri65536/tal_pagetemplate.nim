#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import streams
import unittest

import tal_pagetemplate


proc parse_all(fp: Stream): string =  # {{{1
    var fn = parse_template(fp, "", nil)
    var ret = ""
    while not finished(fn):
        ret &= fn()
    return ret


test "T1-1-1: can parse notmal xml":  # {{{1
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


test "T2-2-1: can parse tal:replace":  # {{{1
    var fp = newStringStream("<a tal:content=\"1\">this</a>")
    check parse_all(fp) == "<a>1</a>"


test "T2-3-1: can parse tal:omit-tag":  # {{{1
    var fp = newStringStream("<a tal:omit-tag=\"\">this</a>")
    check parse_all(fp) == ""


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
