#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
import json
import strformat
import strutils
import tables

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


proc json_to_string(self: JsonNode): string =  # {{{1
    case self.kind:
    of JString:
        return self.str
    else:
        return $self


proc parse_expr_hier(self: JsonNode, parts: seq[string]): JsonNode =  # {{{1
    if len(parts) < 1:
        var obj = self
        return obj
    var part = parts[0]
    if self.kind == JArray:
        try:
            var n = parseInt(part)
            if n < len(self.elems):
                return parse_expr_hier(self[n], parts[1 ..^ 1])
        except ValueError:
            discard
        return newJNull()
    if self.kind != JObject:
        return newJNull()
    if self.hasKey(part):
        return parse_expr_hier(self[part], parts[1 ..^ 1])
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
    var name = parts[0]
    if not self.root.hasKey(name):
        return newJNull()
    var ret = self.root[name].obj
    return parse_expr_hier(ret, parts[1 ..^ 1])


proc parse_expr_exists(self: TalVars, src: string, f_not: bool  # {{{1
                       ): JsonNode =
    proc make_ret(src: bool): JsonNode =
        var src = src
        if f_not:
            src = not src
        return newJBool(src)

    if src.strip() == "null":  # passing the null instance -> true.
        return make_ret(true)
    var tmp = self.parse_expr_path(src)
    debg(fmt"expr-exists: {$tmp}-{f_not}")
    if $tmp != "null":
        return make_ret(true)
    return make_ret(false)


proc parse_expr_nocall(self: TalVars, src: string): JsonNode =  # {{{1
    return newJString(src)


proc parse_expr_string(self: TalVars, src: string): JsonNode =  # {{{1
    proc parse_path(expr: string): string =
        var json = self.parse_expr_path(expr)
        return json_to_string(json)

    var (ret, expr, start) = ("", "", "")
    for ch in src:
        debg(fmt"expr-string: {ch} -> {ret}-{expr}-{start}")
        if start == "$":
            if {'$', ' ', '\t', '\n'}.contains(ch):
                if len(expr) < 1:
                    (start, expr, ret) = ("", "", ret & $ch)
                else:
                    var tmp = parse_path(expr)
                    (start, expr, ret) = ("", "", ret & tmp & $ch)
            elif len(expr) < 1 and ch == '{':
                start = "${"
            else:
                expr &= $ch
        elif len(start) > 0 and ch == '}':  # ${
            var tmp = parse_path(expr)
            (start, expr, ret) = ("", "", ret & tmp)
        elif len(start) > 0:                # ${
            expr &= $ch
        elif ch == '$':
            (start, expr) = ("$", "")
        else:
            ret &= $ch
    if len(expr) > 0:  # met eol in expression
        ret &= parse_path(expr)
    debg(fmt"expr-string: {ret}")
    return newJString(ret)


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

    # FIXME(shimoda): implement.
    when defined(supress_python_expressions):
        return newJString(src)
    else:
        return newJString(src & "(python not supported)")


proc parse_expr_local(self: TalVars, src: string): JsonNode =  # {{{1
    var (n_not, src) = (0, src.strip(leading=true, trailing=false))
    while src.startsWith("not:"):
        src = src[4 ..^ 1].strip(leading=true, trailing=false)
        n_not += 1
    var f_not = (n_not mod 2) == 1

    if src.startsWith("python:"):
        return self.parse_expr_python(src[7 ..^ 1])
    if src.startsWith("string:"):
        return self.parse_expr_string(src[7 ..^ 1])
    if src.startsWith("exists:"):
        return self.parse_expr_exists(src[7 ..^ 1], f_not)
    if src.startsWith("nocall:"):
        return self.parse_expr_nocall(src[7 ..^ 1])

    var src0 = src
    if src.startsWith("path:"):
        src0 = src[5 ..^ 1]
    var ret = self.parse_expr_path(src0)
    if n_not > 0:
        var ret_bool = tales_bool_expr($ret)
        if f_not: ret_bool = not ret_bool
        return newJBool(ret_bool)
    return ret


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


proc push_var(self: var TalVars, name, path: string, vobj: JsonNode): void =  # {{{1
    var varinfo = (path, vobj)
    self.root.add(name, varinfo)


proc push_repeat_var(self: var TalVars,   # {{{1
                     name: string, repeat_var: JsonNode): void =
    var robj: JsonNode
    if self.root.hasKey("repeat"):
        robj = self.root["repeat"].obj
    else:
        robj = newJObject()
        self.root.add("repeat", ("", robj))
    robj.add(name, repeat_var)


proc pop_var(self: var TalVars, name: string): void =  # {{{1
    if not self.root.hasKey(name):
        return
    self.root.del(name)


proc pop_repeat_var(self: var TalVars, name: string): void =  # {{{1
    if not self.root.hasKey("repeat"):
        return
    var robj = self.root["repeat"].obj
    if not robj.hasKey(name):
        return
    robj.delete(name)
    if len(robj) < 1:
        self.root.del("reeat")


iterator parse_repeat_seq*(self: var TalVars, name, path, src: string  # {{{1
                           ): RepeatVars =
    var expr = self.parse_expr_local(src)
    case expr.kind:
    of JNull, JInt, JFloat, JBool, JObject:
        var j = initRepeatVars(0, 1)
        self.push_var(name, path, expr)
        self.push_repeat_var(name, j.to_jsonnode())
        yield j
    of JString:
        var (n, max) = (0, len(expr.str))
        for i in expr.str:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            self.push_var(name, path, newJString($i))
            self.push_repeat_var(name, j.to_jsonnode())
            yield j
            n += 1
    of JArray:
        var (n, max) = (0, len(expr.elems))
        for i in expr.elems:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            self.push_var(name, path, %i)
            self.push_repeat_var(name, j.to_jsonnode)
            yield j
            n += 1
    self.pop_var("repeat")
    self.pop_var(name)


proc parse_define*(self: var TalExpr, vars: var TalVars,  # {{{1
                   expr, path: string): void =
    for src in tal_parse_multi_statements(expr):
        var src = src.strip()
        var f_local = true
        if src.startsWith("local "):
            src = src[6 ..^ 1]
            debg("local detected: " & path)
        elif src.startsWith("global "):
            src = src[7 ..^ 1]
            f_local = false

        var seq = src.strip().split(" ")
        if len(seq) < 2:
            continue  # TODO(shimoda): error handling...
        var name = seq[0]
        var expression = join(seq[1 ..^ 1], " ")
        expression = expression.strip()
        expression = self.expr(expression)
        var var_path = if f_local: path else: ""
        vars.push_var(name, var_path, %expression)


proc leave_define*(self: var TalVars,  # {{{1
                   path: string): void =
    for name, tup in self.root.pairs():
        var path_var = tup.path
        if len(path_var) < 1:
            continue
        if path != path_var:
            continue
        self.pop_var(name)


proc parse_attributes*(self: TalVars, src: string  # {{{1
                       ): Table[string, string] =
    var ret = initTable[string, string]()
    return ret

# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
