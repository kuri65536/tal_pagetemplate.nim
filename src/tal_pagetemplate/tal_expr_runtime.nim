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
import typeinfo
import typetraits

import ./tal_common


type
  runtime_null = enum
    tal_pagetemplate_invalid_indicator

  runtime_buffer = object
    n: BiggestInt
    f: float
    s: string

  runtime_repeat = object
    names: seq[string]
    vars: seq[RepeatVars]


var rt_repeat = runtime_repeat(names: @[], vars: @[])
var rt_buffer = runtime_buffer()


proc make_null(): Any =  # {{{1
    var ret = runtime_null.tal_pagetemplate_invalid_indicator
    return toAny(ret)


proc any_serialize*(self: Any): string =  # {{{1
    case self.kind
    of akSequence, akArray:
        var ret = ""
        var (h, t) = if self.kind == akArray: ("(", ")")
                     else:                    ("[", "]")
        for i in 0 .. len(self) - 1:
            ret &= ", " & any_serialize(self[i])
        if len(ret) < 1:
            return h & t
        return h & ret[2 ..^ 1] & t
    of akTuple, akObject:
        var ret = ""
        var (h, t) = if self.kind == akTuple: ("(", ")")
                     else:                    ("{", "}")
        for name, fld in self.fields():
            var tmp = any_serialize(fld)
            ret &= fmt", ""{name}"": {tmp}"
        if len(ret) < 1:
            return h & t
        return h & ret[2 ..^ 1] & t
    of akSet:
        var ret = ""
        for i in self.elements():
            var tmp = $i  # FIXME(shimoda): any_serialize(self[i])
            ret &= fmt", {tmp}"
        if len(ret) < 1:
            return "{0}"
        return "{" & ret[2 ..^ 1] & "}"
    of akInt:     return $(self.getInt())
    of akInt8:    return $(self.getInt8())
    of akInt16:   return $(self.getInt16())
    of akInt32:   return $(self.getInt32())
    of akInt64:   return $(self.getInt64())
    of akUInt:    return $(self.getUInt())
    of akUInt8:   return $(self.getUInt8())
    of akUInt16:  return $(self.getUInt16())
    of akUInt32:  return $(self.getUInt32())
    of akUInt64:  return $(self.getUInt64())
    of akFloat:   return $(self.getFloat())
    of akFloat32: return $(self.getFloat32())
    of akFloat64: return $(self.getFloat64())
    of akChar:    return "'" & $self.getChar() & "'"
    of akString:  return "\"" & self.getString() & "\""
    of akBool:    return $(self.getBool())
    of akEnum:
        if self.getEnumField() == "tal_pagetemplate_invalid_indicator":
            return ""  # refer make_null
        return self.getEnumField()
    else:
        # akBool, akEnum:
        return $self


proc parse_expr_hier(self: Any, parts: seq[string]): Any =  # {{{1
    if len(parts) < 1:
        return self
    var part = parts[0]
    # debg(fmt"expr_hier: {part}...")
    case self.kind():
    of akArray, akSequence:
        try:
            var n = parseInt(part)
            if n < len(self):
                return parse_expr_hier(self[n], parts[1 ..^ 1])
        except ValueError:
            discard
    of akObject, akTuple:
        try:
            var tmp = self[part]
            return parse_expr_hier(tmp, parts[1 ..^ 1])
        except ValueError:
            debg(fmt"rtti-expr: can't find '{part}'")
    else:
        discard
    return make_null()


proc tales_path_runtime*(self: TalVars, parts: seq[string]): Any =  # {{{1
    var name = parts[0]
    # debg(fmt"tales_path: {name}...")
    if not self.root_runtime.hasKey(name):
        return make_null()
    var ret = self.root_runtime[name].obj
    debg(fmt"rtti-expr: {name}-{ret.kind}")
    return parse_expr_hier(ret, parts[1 ..^ 1])


proc tales_expr_runtime*(self: TalVars, expr: string): Any =  # {{{1
    var (ans, parts) = tales_split_path(expr)
    if len(parts) < 1:
        case ans.kind:
        of JInt:   rt_buffer.n = ans.num;  return toAny(rt_buffer.n)
        of JFloat: rt_buffer.f = ans.fnum; return toAny(rt_buffer.f)
        of JNull:  return make_null()
        else:      assert false
    return self.tales_path_runtime(parts)


proc tales_meta_runtime*(self: TalVars, meta: string, exprs: seq[string]  # {{{1
                         ): Any =
    if meta == "" and len(exprs) == 1:
        return self.tales_expr_runtime(exprs[0])

    var (ret, n) = ("", 0)
    for ch in meta:
        if ch == '\t':
            var tmp = self.tales_expr_runtime(exprs[n])
            ret &= any_serialize(tmp)
            n += 1
        else:
            ret &= $ch
    rt_buffer.s = ret
    return toAny(rt_buffer.s)


proc push_var(self: var TalVars, name, path: string, vobj: Any): void =  # {{{1
    var varinfo = (path, vobj)
    self.root_runtime[name] = varinfo


proc push_repeat_var(self: var TalVars,   # {{{1
                     name: string, repeat_var: RepeatVars): void =
    if self.root_runtime.hasKey("repeat"):
        discard
    else:
        var tmp = toAny(rt_repeat)
        self.root_runtime["repeat"] = ("", tmp)
        rt_repeat.names = @[]
        rt_repeat.vars = @[]
    rt_repeat.names.add(name)
    rt_repeat.vars.add(repeat_var)


proc pop_var_runtime*(self: var TalVars, name: string): void =  # {{{1
    if not self.root_runtime.hasKey(name):
        return
    self.root_runtime.del(name)


proc pop_repeat_var_runtime*(self: var TalVars, name: string): void =  # {{{1
    if not self.root_runtime.hasKey("repeat"):
        return
    var n = rt_repeat.names.find(name)
    if n < 0:
        return
    rt_repeat.names.del(n)
    rt_repeat.vars.del(n)


iterator parse_repeat_seq_runtime*(self: var TalVars,  # {{{1
                                   name, path: string, expr: Any): RepeatVars =
    case expr.kind:
    of akString:
        var tmp = $expr
        var (n, max) = (0, len(tmp))
        for i in tmp:
            self.pop_repeat_var_runtime(name)
            self.pop_var_runtime(name)
            var j = initRepeatVars(n, max)
            var tmp = i
            self.push_var(name, path, toAny(tmp))
            self.push_repeat_var(name, j)
            yield j
            n += 1
    of akArray, akSequence:
        var (n, max) = (0, len(expr))
        for i in 0 .. max - 1:
            self.pop_repeat_var_runtime(name)
            self.pop_var_runtime(name)
            var j = initRepeatVars(n, max)
            var tmp = expr[i]
            self.push_var(name, path, tmp)
            self.push_repeat_var(name, j)
            yield j
            n += 1
    of akSet:
      when NimMajor > 0:
            ## todo: e.elements cause segfault
            var j = initRepeatVars(0, 1)
            self.push_var(name, path, toAny(rt_buffer.n))
            self.push_repeat_var(name, j)
            yield j
            self.pop_repeat_var_runtime(name)
            self.pop_var_runtime(name)
      else:
        var (n, max) = (0, 0)
        for i in expr.elements():
            max += 1
        for i in expr.elements():
            var j = initRepeatVars(n, max)
            rt_buffer.n = i
            self.push_var(name, path, toAny(rt_buffer.n))
            self.push_repeat_var(name, j)
            yield j
            self.pop_repeat_var_runtime(name)
            self.pop_var_runtime(name)
            n += 1
    else:  # akObject, akTuple, ..., akInt or etc
        var j = initRepeatVars(0, 1)
        self.push_var(name, path, expr)
        self.push_repeat_var(name, j)
        yield j


proc copy_from*(self: var Table[string, tuple[path: string, obj: Any]],  # {{{1
                vars: Any): void =
    case vars.kind:
    of akTuple, akObject:
        for name, fld in vars.fields():
            debg(fmt"copy_rtti: {name}-{fld.kind}")
            self[name] = ("", fld)
    of akArray, akSequence:
        var max = len(vars)
        for i in 0 .. max:
            var fld = vars[i]
            debg(fmt"rtti-copy: {i}-{fld.kind}")
            self[$i] = ("", fld)
    else:
        discard

# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
