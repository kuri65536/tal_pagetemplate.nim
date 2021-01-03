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
import tables
import typeinfo

import ./tal_common


proc json_to_string*(self: JsonNode): string =  # {{{1
    case self.kind:
    of JString:
        return self.str
    else:
        return $self


proc make_bool*(src: bool): string =  # {{{1
    return $newJBool(src)


proc make_repeatvar(self: RepeatVars): JsonNode =  # {{{1
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


proc tales_path_json(self: TalVars, parts: seq[string]): JsonNode =  # {{{1
    var name = parts[0]
    if not self.root.hasKey(name):
        return newJNull()
    var ret = self.root[name].obj
    return parse_expr_hier(ret, parts[1 ..^ 1])


proc tales_expr_json(self: TalVars, expr: string): JsonNode =  # {{{1
    var (ans, parts) = tales_split_path(expr)
    if len(parts) < 1:
        return ans
    return self.tales_path_json(parts)


proc tales_meta_json*(self: TalVars, meta: string, exprs: seq[string]  # {{{1
                      ): JsonNode =
    if meta == "" and len(exprs) == 1:
        return self.tales_expr_json(exprs[0])

    var (ret, n) = ("", 0)
    for ch in meta:
        if ch == '\t':
            var tmp = self.tales_expr_json(exprs[n])
            ret &= json_to_string(tmp)
            n += 1
        else:
            ret &= $ch
    return newJString(ret)


proc push_var*(self: var TalVars, name, path, vobj: string): void =  # {{{1
    var vobj = json.parseJson(vobj)
    var varinfo = (path, vobj)
    self.root.add(name, varinfo)


proc push_repeat_var*(self: var TalVars,   # {{{1
                     name: string, repeat_var: JsonNode): void =
    var robj: JsonNode
    if self.root.hasKey("repeat"):
        robj = self.root["repeat"].obj
    else:
        robj = newJObject()
        self.root.add("repeat", ("", robj))
    robj.add(name, repeat_var)


proc pop_var*(self: var TalVars, name: string): void =  # {{{1
    if not self.root.hasKey(name):
        return
    self.root.del(name)


proc pop_repeat_var*(self: var TalVars, name: string): void =  # {{{1
    if not self.root.hasKey("repeat"):
        return
    var robj = self.root["repeat"].obj
    if not robj.hasKey(name):
        return
    robj.delete(name)
    if len(robj) < 1:
        self.root.del("reeat")


iterator parse_repeat_seq_json*(self: var TalVars, name, path: string,  # {{{1
                                expr: JsonNode): RepeatVars =
    case expr.kind:
    of JNull, JInt, JFloat, JBool, JObject:
        var j = initRepeatVars(0, 1)
        self.push_var(name, path, $expr)
        self.push_repeat_var(name, j.make_repeatvar())
        yield j
    of JString:
        var (n, max) = (0, len(expr.str))
        for i in expr.str:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            self.push_var(name, path, $i)
            self.push_repeat_var(name, j.make_repeatvar())
            yield j
            n += 1
    of JArray:
        var (n, max) = (0, len(expr.elems))
        for i in expr.elems:
            self.pop_repeat_var(name)
            self.pop_var(name)
            var j = initRepeatVars(n, max)
            self.push_var(name, path, $i)
            self.push_repeat_var(name, j.make_repeatvar())
            yield j
            n += 1


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
