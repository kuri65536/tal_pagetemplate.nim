#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import json
import strutils

import ./tal_repeat


proc roman(n: int): string =
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


proc initRepeatVars(obj: JsonNode, n, max: int): RepeatVars =  # {{{1
    proc letter(): string =
        var tmp = n
        var ret = ""
        while tmp != 0:
            var i = tmp mod 25
            tmp = tmp div 25
            ret = ret & $chr(ord('a') + i)
        return ret

    var ret = RepeatVars(
        n_index: n, n_number: n + 1,
        f_even: (n mod 2) == 0, f_start: n == 0,
        f_odd: (n mod 2) == 1, f_end: n == max,
        letter: letter(), roman: roman(n + 1),
        )
    ret.Letter = ret.letter.toUpper()
    ret.Roman = ret.roman.toUpper()
    return ret


proc parse_expr_path(src: string): JsonNode =  # {{{1
    return newJString(src)


proc parse_expr_exists(src: string): JsonNode =  # {{{1
    return newJBool(false)


proc parse_expr_nocall(src: string): JsonNode =  # {{{1
    return newJString(src)


proc parse_expr_string(src: string): JsonNode =  # {{{1
    return newJString(src)


proc parse_expr_python(src: string): JsonNode =  # {{{1
    var tmp = src.strip()
    try:
        return newJInt(parseInt(tmp))
    except ValueError:
        discard
    try:
        return newJFloat(parseFloat(tmp))
    except ValueError:
        discard
    # TODO(shimoda): implement.
    return newJString("")


proc parse_expr_local(src: string): JsonNode =  # {{{1
    if src.startsWith("python:"):
        return parse_expr_python(src[7 ..^ 1])
    if src.startsWith("string:"):
        return parse_expr_string(src[7 ..^ 1])
    if src.startsWith("exists:"):
        return parse_expr_exists(src[7 ..^ 1])
    if src.startsWith("nocall:"):
        return parse_expr_nocall(src[7 ..^ 1])

    var src0 = src
    if src.startsWith("not:"):
        src0 = src[4 ..^ 1]
    elif src.startsWith("path:"):
        src0 = src[5 ..^ 1]
    return parse_expr_path(src0)


iterator parse_repeat_seq*(src: string): RepeatVars =  # {{{1
    var n = 0
    var ret = RepeatVars()
    var expr = parse_expr_local(src)
    case expr.kind:
    of JNull, JInt, JFloat, JBool:
        yield initRepeatVars(expr, 0, 1)
    of JObject:
        yield initRepeatVars(expr, 0, 1)
    of JString:
        var max = len(expr.str)
        for i in expr.str:
            yield initRepeatVars(newJString($i), n, max)
            n += 1
    of JArray:
        var max = len(expr.elems)
        for i in expr.elems:
            yield initRepeatVars(i, n, max)
            n += 1


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
