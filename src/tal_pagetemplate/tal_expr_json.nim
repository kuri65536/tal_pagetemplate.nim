#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
import json
import strutils

import ./tal_common
import ./tal_repeat


proc initRepeatVars(n, max: int): RepeatVars =  # {{{1
    var ret = RepeatVars(
        n_index: n, n_number: n + 1, n_length: max,
        f_even: (n mod 2) == 0, f_start: n == 0,
        f_odd: (n mod 2) == 1, f_end: n == max - 1,
        letter: tal_repeat_letters(n),
        roman: tal_repeat_romans(n + 1),
        )
    ret.Letter = ret.letter.toUpper()
    ret.Roman = ret.roman.toUpper()
    return ret


proc to_jsonnode(self: RepeatVars): JsonNode =  # {{{1
    var ret = newJObject()
    ret.add("index", newJInt(self.n_index))
    ret.add("number", newJInt(self.n_number))
    ret.add("even", newJBool(self.f_even))
    ret.add("odd", newJBool(self.f_odd))
    ret.add("start", newJBool(self.f_start))
    ret.add("end", newJBool(self.f_end))
    ret.add("length", newJInt(self.n_length))
    ret.add("letter", newJString(self.letter))
    ret.add("Letter", newJString(self.Letter))
    ret.add("roman", newJString(self.roman))
    ret.add("Roman", newJString(self.Roman))
    return ret


proc parse_expr_hier(self: JsonNode, parts: seq[string]): JsonNode =  # {{{1
    if len(parts) < 1:
        return self
    if self.hasKey(parts[0]):
        return parse_expr_hier(self[parts[0]], parts[1 ..^ 1])
    return newJNull()


proc parse_expr_path(self: TalVars, src: string): JsonNode =  # {{{1
    if len(src) < 1:
        return newJString("")
    var tmp = src.strip()
    try:
        return newJInt(parseInt(tmp))
    except ValueError:
        discard
    try:
        return newJFloat(parseFloat(tmp))
    except ValueError:
        discard

    var parts = src.split("/")
    return parse_expr_hier(self.root, parts)


proc parse_expr_exists(self: TalVars, src: string): JsonNode =  # {{{1
    return newJBool(false)


proc parse_expr_nocall(self: TalVars, src: string): JsonNode =  # {{{1
    return newJString(src)


proc parse_expr_string(self: TalVars, src: string): JsonNode =  # {{{1
    return newJString(src)


proc parse_expr_python(self: TalVars, src: string): JsonNode =  # {{{1
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


proc parse_expr_local(self: TalVars, src: string): JsonNode =  # {{{1
    if src.startsWith("python:"):
        return self.parse_expr_python(src[7 ..^ 1])
    if src.startsWith("string:"):
        return self.parse_expr_string(src[7 ..^ 1])
    if src.startsWith("exists:"):
        return self.parse_expr_exists(src[7 ..^ 1])
    if src.startsWith("nocall:"):
        return self.parse_expr_nocall(src[7 ..^ 1])

    var src0 = src
    if src.startsWith("not:"):
        src0 = src[4 ..^ 1]
    elif src.startsWith("path:"):
        src0 = src[5 ..^ 1]
    return self.parse_expr_path(src0)


proc parse_expr*(self: TalVars, src: string): string =  # {{{1
    var expr = self.parse_expr_local(src)
    case expr.kind:
    of JNull, JInt, JFloat, JBool:
        return $expr  # TODO(shimoda): need test
    of JObject:
        return $expr  # TODO(shimoda): need test
    of JString:
        return expr.str
    of JArray:
        return $expr  # TODO(shimoda): need test
    return $expr


proc push_var(self: var TalVars, name: string, vobj: JsonNode): void =  # {{{1
    self.root.add(name, vobj)


proc push_repeat_var(self: var TalVars,   # {{{1
                     name: string, repeat_var: JsonNode): void =
    var robj: JsonNode
    if self.root.hasKey("repeat"):
        robj = self.root["repeat"]
    else:
        robj = newJObject()
        self.root.add("repeat", robj)
    robj.add(name, repeat_var)


proc pop_var(self: var TalVars, name: string): void =  # {{{1
    if not self.root.hasKey(name):
        return
    self.root.delete(name)


proc pop_repeat_var(self: var TalVars, name: string): void =  # {{{1
    if not self.root.hasKey("repeat"):
        return
    var robj = self.root["repeat"]
    if not robj.hasKey(name):
        return
    robj.delete(name)


iterator parse_repeat_seq*(self: var TalVars, name, src: string): RepeatVars =  # {{{1
    var expr = self.parse_expr_local(src)
    case expr.kind:
    of JNull, JInt, JFloat, JBool, JObject:
        var j = initRepeatVars(0, 1)
        self.push_var(name, expr)
        self.push_repeat_var(name, j.to_jsonnode())
        yield j
    of JString:
        var (n, max) = (0, len(expr.str))
        for i in expr.str:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            self.push_var(name, newJString($i))
            self.push_repeat_var(name, j.to_jsonnode())
            yield j
            n += 1
    of JArray:
        var (n, max) = (0, len(expr.elems))
        for i in expr.elems:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            self.push_var(name, %i)
            self.push_repeat_var(name, j.to_jsonnode)
            yield j
            n += 1
    self.pop_var("repeat")
    self.pop_var(name)


proc parse_define*(self: var TalExpr, vars: var TalVars,  # {{{1
                   expr: string): void =
    var src = expr.strip()
    if src.startsWith("local "):
        # TODO(shimoda): var pop at the end of tag.
        src = src[6 ..^ 1]
    elif src.startsWith("global "):
        src = src[7 ..^ 1]

    for statement in src.split(";"):
        var seq = statement.split(" ")
        if len(seq) < 2:
            continue  # TODO(shimoda): error handling...
        var name = seq[0]
        var expression = join(seq[1 ..^ 1], " ")
        expression = expression.strip()
        expression = self.expr(expression)
        vars.push_var(name, %expression)

# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
