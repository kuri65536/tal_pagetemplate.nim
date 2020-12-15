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


test "T1-1-1: can parse":
    var fp = newStringStream("<a>this</a>")
    check parse_all(fp) == "<a>this</a>"

# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
