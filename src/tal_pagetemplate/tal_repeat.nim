#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
import json
import parsexml
import strformat
import strutils
import tables

import ./tal_common


proc initTagRepeat*(elem, path, name, expr: string, attrs: Attrs,  # {{{1
                    exprs: TalExpr): TagRepeat =
    var ret = TagRepeat(elem: elem, name: name, expr: expr)
    ret.path = path
    ret.attrs = attrs  # copy.
    ret.current = RepeatStatus()
    ret.exprs = exprs

    ret.attrs.del("tal:repeat")
    ret.attrs.del("tal:replace")  # which is significant? replace or repeat?
    return ret


proc debg(msg: string): void =  # {{{1
    discard


proc tal_repeat_romans*(n: int): string =  # {{{1
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


proc tal_repeat_letters*(n: int): string =  # {{{1
    var (f, tmp) = (true, n)
    var ret = ""
    while tmp > 0 or f:
        f = false
        var i = tmp mod 25
        tmp = tmp div 25
        debg(fmt"letters: {n}->{i},{tmp}")
        ret = ret & $chr(ord('a') + i)
    return ret


proc render_repeat_starttag(self: var TagRepeat,  # {{{1
                            name: string, attrs: Attrs): string =
    if len(self.current.element_ignore) > 0:
        return ""

    # TODO(shimoda): unified with normal parsing.
    if attrs.hasKey("tal:define"):
        var expr = attrs["tal:define"]
        self.exprs.defvars(expr, self.path)  # TODO(shimoda): path in repeat

    if attrs.hasKey("tal:replace"):
        var expr = attrs["tal:replace"]
        self.current.element_ignore = name
        return self.exprs.expr(expr)
    if attrs.hasKey("tal:content"):
        var ret = fmt"<{name}>"
        var expr = attrs["tal:content"]
        # TODO(shimoda): ret &= render_attrs(self.elem, "", attrs)
        ret &= self.exprs.expr(expr)
        ret &= "</" & name & ">"
        self.current.element_ignore = name
        return ret

    # TODO(shimoda): ret &= render_attrs(i.elem, "", i.attrs)
    return fmt"<{name}>"


proc render_repeat_endtag(self: var TagRepeat, name: string): string =  # {{{1
    if name == self.current.element_ignore:
        self.current.element_ignore = ""
        return ""

    return fmt"</{name}>"


proc parse_tagend_render_repeat(self: var TagRepeat,  # {{{1
                                var_repeat: RepeatVars): string =
    proc new_attrs(): Attrs =
        return initOrderedTable[string, string]()

    var stack: seq[string] = @[]
    var attrs = new_attrs()
    var ret = ""
    for i in self.xml:
        debg(fmt"looping: {$i.kind}-{ret}")
        case i.kind:
        of xmlElementEnd:
            ret &= self.render_repeat_endtag(i.data)
        of xmlElementStart, xmlElementClose:
            var d = self.render_repeat_starttag(i.data, attrs)
            attrs = new_attrs()
            ret &= d
        of xmlElementOpen:
            attrs = new_attrs()
        of xmlAttribute:
            var seq = i.data.split("\t")
            if len(seq) > 1:
                attrs[seq[0]] = join(seq[1 ..^ 1], "\t")
            else:
                echo "???"
        of xmlCharData:
            if len(self.current.element_ignore) < 1:
                ret &= i.data
        of xmlWhitespace:
            if len(self.current.element_ignore) < 1:
                ret &= i.data
        of xmlCData:
            if len(self.current.element_ignore) < 1:
                ret &= i.data
        of xmlSpecial:
            if len(self.current.element_ignore) < 1:
                ret &= i.data
        of xmlEntity:
            if len(self.current.element_ignore) < 1:
                ret &= i.data
        of xmlComment:
            if len(self.current.element_ignore) < 1:
                ret &= fmt"<!-- {i.data} -->"
        of xmlPI:
            ret &= i.data
        else:
            discard  # will not have Eof, Error.
    return ret

proc parse_push(self: var TagRepeat, kind: XmlEventKind, data: string  # {{{1
                ): void =
    self.xml.add(TagRepeat0(kind: kind, data: data))


proc render_repeat_tag_start(self: TagRepeat, vars: RepeatVars  # {{{1
                             ): tuple[f: bool, d: string] =
    if self.attrs.hasKey("tal:omit-tag"):
        var expr = self.attrs["tal:omit-tag"]
        expr = self.exprs.expr(expr)
        if tal_omit_tag_is_enabled(expr):
            return (false, "")

    # ignore tal:replace

    var ret = fmt"<{self.elem}"
    for attr, value in self.attrs.pairs():
        if attr == "tal:content":
            continue
        ret &= " \"{attr}\"=\"{value}\""
    ret &= ">"

    if self.attrs.hasKey("tal:content"):
        var expr = self.attrs["tal:content"]
        expr = self.exprs.expr(expr)
        ret &= expr
        debg(fmt"tag-start(content): {ret}")
        return (false, ret)

    debg(fmt"tag-start: {ret}")
    return (true, ret)


proc parse_tagend(self: var TagRepeat, name: string  # {{{1
                  ): tuple[d: string, f: bool] =
    if name != self.elem:
        debg(fmt"found '>' for {name}")
        self.parse_push(xmlElementEnd, name)
        return ("", true)

    debg("finishing repeat...")
    var (tags, iter) = ("", self.exprs.repeat(self.path, self.name, self.expr))
    var i = iter()
    while not finished(iter):
        var (f, d) = self.render_repeat_tag_start(i)
        tags &= d
        if f:
            tags &= self.parse_tagend_render_repeat(i)
        tags &= fmt"</{self.elem}>"
        i = iter()
    return (tags, false)


proc parse_tree*(self: var TagRepeat, x: XmlParser  # {{{1
                 ): tuple[d: string, f: bool] =
    var (d, f) = ("", true)
    case x.kind
    of xmlEof:
        return self.parse_tagend(self.elem)
    of xmlElementEnd:
        return self.parse_tagend(x.elementName)
    of xmlElementStart, xmlElementOpen:
        self.parse_push(x.kind, x.elementName)
        self.elem_prev = x.elementName
    of xmlElementClose:
        self.parse_push(x.kind, self.elem_prev)
    of xmlAttribute:
        self.parse_push(x.kind, x.attrKey & "\t" & x.attrValue)
    of xmlCharData, xmlWhitespace, xmlCData, xmlSpecial:
        self.parse_push(x.kind, x.charData)
    of xmlEntity:
        self.parse_push(x.kind, x.entityName)
    of xmlComment:
        self.parse_push(x.kind, x.charData)  # "<!-- $1 -->"
    of xmlPI:
        self.parse_push(x.kind, fmt"<? {x.piName} ## {x.piRest} ?>")
    of xmlError:        echo(x.errorMsg())
    return (d, true)


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
