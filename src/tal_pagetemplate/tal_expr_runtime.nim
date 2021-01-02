#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
import sequtils
import strformat
import strutils
import tables
import typeinfo

import ./tal_common


type
  runtime_null = object
    n: int

  runtime_repeat = object
    names: seq[string]
    vars: seq[RepeatVars]


var null_object = runtime_null()


proc make_null(): Any =  # {{{1
    return toAny(null_object)


proc any_deserialize(self: string): Any =  # {{{1
    discard


proc any_serialize*(self: Any): string =  # {{{1
    case self.kind
    of akSequence, akArray:
        var ret = ""
        var (h, t) = if self.kind == akArray: ("(", ")")
                     else:                    ("[", "]")
        for i in 0 .. len(self):
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
            ret &= fmt", {i}"
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
    of akChar:    return $(self.getChar())
    of akString:  return self.getString()
    of akBool:    return $(self.getBool())
    else:
        # akBool, akEnum:
        return $self


proc parse_expr_hier(self: Any, parts: seq[string]): Any =  # {{{1
    if len(parts) < 1:
        return self
    var part = parts[0]
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
            discard
    else:
        discard
    return make_null()


proc parse_expr_runtime*(self: TalVars, parts: seq[string]): Any =  # {{{1
    var name = parts[0]
    if not self.root_runtime.hasKey(name):
        return make_null()
    var ret = self.root_runtime[name].obj
    echo(fmt"rtti-expr: {name}-{ret.kind}")
    return parse_expr_hier(ret, parts[1 ..^ 1])


proc push_var(self: var TalVars, name, path: string, vobj: Any): void =  # {{{1
    var varinfo = (path, vobj)
    self.root_runtime.add(name, varinfo)


proc push_repeat_var(self: var TalVars,   # {{{1
                     name: string, repeat_var: RepeatVars): void =
    var robj: runtime_repeat
    if self.root_runtime.hasKey("repeat"):
        var tmp = self.root_runtime["repeat"].obj
        robj = cast[runtime_repeat](tmp)
    else:
        robj = runtime_repeat(vars: @[])
        var tmp = toAny(robj)
        self.root_runtime.add("repeat", ("", tmp))
    robj.names.add(name)
    robj.vars.add(repeat_var)


proc pop_var(self: var TalVars, name: string): void =  # {{{1
    if not self.root_runtime.hasKey(name):
        return
    self.root_runtime.del(name)


proc pop_repeat_var(self: var TalVars, name: string): void =  # {{{1
    if not self.root_runtime.hasKey("repeat"):
        return
    var tmp = self.root_runtime["repeat"].obj
    var robj = cast[runtime_repeat](tmp)
    var n = robj.names.find(name)
    if n < 0:
        return
    robj.names.del(n)
    robj.vars.del(n)


iterator parse_repeat_seq_runtime*(self: var TalVars, name, path, src: string  # {{{1
                                   ): RepeatVars =
    var expr = any_deserialize(src)
    case expr.kind:
    of akString:
        var tmp = $expr
        var (n, max) = (0, len(tmp))
        for i in tmp:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            var tmp = i
            self.push_var(name, path, toAny(tmp))
            self.push_repeat_var(name, j)
            yield j
            n += 1
    of akArray, akSequence:
        var (n, max) = (0, len(expr))
        for i in 0 .. max:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            var tmp = expr[i]
            self.push_var(name, path, tmp)
            self.push_repeat_var(name, j)
            yield j
            n += 1
    else:
        var j = initRepeatVars(0, 1)
        self.push_var(name, path, expr)
        self.push_repeat_var(name, j)
        yield j


proc copy_from*(self: var Table[string, tuple[path: string, obj: Any]],  # {{{1
                vars: Any): void =
    case vars.kind:
    of akTuple, akObject:
        for name, fld in vars.fields():
            echo(fmt"copy_rtti: {name}-{fld.kind}")
            self.add(name, ("", fld))
    of akArray, akSequence:
        var max = len(vars)
        for i in 0 .. max:
            var fld = vars[i]
            echo(fmt"rtti-copy: {i}-{fld.kind}")
            self.add($i, ("", fld))
    else:
        discard

# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
