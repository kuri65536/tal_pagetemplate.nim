#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import json


type
  TalVars* = ref object of RootObj  # {{{1
    when true:
        root*: JsonNode
    else:
        root*: any

  RepeatVars* = ref object of RootObj  # {{{1
    n_index*, n_number*: int
    f_even*, f_odd*: bool
    f_start*, f_end*: bool
    letter*, Letter*: string
    roman*, Roman*: string


proc tal_repeat_romans*(n: int): string =
    let seqi = ["", "i", "ii", "iii", "iv",
                    "v", "vi", "vii", "viii", "ix"]
    let seqx = ["", "x", "xx", "xxx", "xl",
                    "l", "lx", "lxx", "lxxx", "xc"]
    let seqc = ["", "c", "cc", "ccc", "cd",
                    "d", "dc", "dcc", "dccc", "cm"]
    let seqm = ["", "m", "mm", "mmm", "",
                "", "", "", "", ""]
    proc conv(j: int, romans: array[10, string]): string =
        var i = j mod 10
        if i > 9: return ""
        return romans[i]
    var ret = conv(n, seqi)
    ret = conv(n div 10, seqx) & ret
    ret = conv(n div 100, seqc) & ret
    ret = conv(n div 1000, seqm) & ret
    return ret


proc tal_repeat_letters*(n: int): string =
    var tmp = n
    var ret = ""
    while tmp != 0:
        var i = tmp mod 25
        tmp = tmp div 25
        ret = ret & $chr(ord('a') + i)
    return ret


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
