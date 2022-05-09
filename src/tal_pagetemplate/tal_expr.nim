#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
import strformat
import strutils
import tables
import typeinfo

import ./tal_common

import ./tal_expr_json
import ./tal_expr_runtime


proc tales_parse*(self: TalVars, src: string): string


proc parse_expr_exists(self: TalVars, src: string, f_not: bool  # {{{1
                       ): string =
    proc make_ret(src: bool): string =
        var src = src
        if f_not:
            src = not src
        return make_bool(src)

    if src.strip() == "null":  # passing the null instance -> true.
        return make_ret(true)
    var tmp = self.tales_parse(src)
    debg(fmt"expr-exists: {$tmp}-{f_not}")
    if $tmp != "null":
        return make_ret(true)
    return make_ret(false)


proc parse_expr_nocall(self: TalVars, src: string): string =  # {{{1
    return src


proc parse_expr_string(self: TalVars, src: string  # {{{1
                       ): tuple[meta: string, exprs: seq[string]] =
    var exprs: seq[string] = @[]
    var (ret, expr, start) = ("", "", "")
    for ch in src:
        debg(fmt"expr-string: {ch} -> {ret}-{expr}-{start}")
        if start == "$":
            if {'$', ' ', '\t', '\n'}.contains(ch):
                if len(expr) < 1:
                    (start, expr, ret) = ("", "", ret & $ch)
                else:
                    exprs.add(expr)
                    (start, expr, ret) = ("", "", ret & "\t" & $ch)
            elif len(expr) < 1 and ch == '{':
                start = "${"
            else:
                expr &= $ch
        elif len(start) > 0 and ch == '}':  # ${
            exprs.add(expr)
            (start, expr, ret) = ("", "", ret & "\t")
        elif len(start) > 0:                # ${
            expr &= $ch
        elif ch == '$':
            (start, expr) = ("$", "")
        else:
            ret &= $ch
    if len(expr) > 0:  # met eol in expression
        exprs.add(expr)
        ret &= "\t"
    debg(fmt"expr-string: {ret}-{exprs}")
    return (ret, exprs)


proc parse_expr_python(self: TalVars, src: string): string =  # {{{1
    var tmp = src.strip()
    try:
        return $parseInt(tmp)
    except ValueError:
        discard
    try:
        return $parseFloat(tmp)
    except ValueError:
        discard

    # FIXME(shimoda): implement.
    when defined(supress_python_expressions):
        return src
    else:
        return src & "(python not supported)"


proc tales_parse_meta*(self: TalVars, src: string  # {{{1
                       ): tuple[meta: string, exprs: seq[string]] =
    var (n_not, src) = (0, src.strip(leading=true, trailing=false))
    while src.startsWith("not:"):
        src = src[4 ..^ 1].strip(leading=true, trailing=false)
        n_not += 1
    var f_not = (n_not mod 2) == 1

    if src.startsWith("python:"):
        return (self.parse_expr_python(src[7 ..^ 1]), @[])
    if src.startsWith("string:"):
        return self.parse_expr_string(src[7 ..^ 1])
    if src.startsWith("exists:"):
        return (self.parse_expr_exists(src[7 ..^ 1], f_not), @[])
    if src.startsWith("nocall:"):
        return (self.parse_expr_nocall(src[7 ..^ 1]), @[])

    var src0 = src
    if src.startsWith("path:"):
        src0 = src[5 ..^ 1]
    if n_not > 0:
        var ret = self.tales_parse(src0)
        debg(fmt"tales_parse: {src0}->{ret}")
        var ret_bool = tales_bool_expr($ret)
        if f_not: ret_bool = not ret_bool
        return (make_bool(ret_bool), @[])
    return ("", @[src0])


proc tales_parse*(self: TalVars, src: string): string =  # {{{1
    var (meta, exprs) = self.tales_parse_meta(src)
    if self.f_json:
        var tmp = self.tales_meta_json(meta, exprs)
        debg(fmt"tales_expr-json: {json_to_string(tmp)}")
        return json_to_string(tmp)
    else:
        var tmp = self.tales_meta_runtime(meta, exprs)
        var ret = any_serialize(tmp)
        if tmp.kind == akString:
            ret = ret[1 ..^ 2]  # remove "
        elif tmp.kind == akChar:
            ret = ret[1 ..^ 2]  # remove '
        return ret


proc push_var(self: var TalVars, name, path, expr_str: string): void =  # {{{1
    if self.f_json:
        self.push_var_json(name, path, expr_str)
    else:
        self.push_var_runtime(name, path, expr_str)


proc pop_var(self: var TalVars, name: string): void =  # {{{1
    if self.f_json:
        self.pop_var_json(name)
    else:
        self.pop_var_runtime(name)


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
        vars.push_var(name, var_path, expression)


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
