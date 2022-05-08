#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
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


proc render_in_repeat_starttag(self: var TagRepeat,  # {{{1
                            name: string, attrs: var Attrs): string =
    if len(self.current.element_ignore) > 0:
        return ""

    var (n, d) = self.exprs.render_starttag(self.path, name, attrs)

    if n.contains(tag_in_replace):
        self.current.element_ignore = name
        return d
    if n.contains(tag_in_content):
        self.current.element_ignore = name
        if n.contains(tag_in_omit_tag):
            return d
        return d & render_endtag(name)
    return d


proc render_repeat_endtag(self: var TagRepeat, name: string): string =  # {{{1
    if name == self.current.element_ignore:
        self.current.element_ignore = ""
        return ""

    return render_endtag(name)


proc parse_tagend_render_repeat(self: var TagRepeat,  # {{{1
                                var_repeat: RepeatVars): string =
    var attrs = newAttrs()
    var ret = ""
    for i in self.xml:
        debg(fmt"looping: {$i.kind}-{ret}")
        case i.kind:
        of xmlElementEnd:
            ret &= self.render_repeat_endtag(i.data)
        of xmlElementStart, xmlElementClose:
            var d = self.render_in_repeat_starttag(i.data, attrs)
            attrs = newAttrs()
            ret &= d
        of xmlElementOpen:
            attrs = newAttrs()
        of xmlAttribute:
            var seq = i.data.split("\t")
            if len(seq) > 1:
                attrs[seq[0]] = join(seq[1 ..^ 1], "\t")
            else:
                echo "???"
        of xmlCData, xmlCharData, xmlComment, xmlEntity,
           xmlSpecial, xmlPI, xmlWhitespace:  # will not have except CharData
            if len(self.current.element_ignore) < 1:
                ret &= i.data
        of xmlEof, xmlError:
            discard  # will not have Eof, Error.
    return ret

proc parse_push(self: var TagRepeat, kind: XmlEventKind, data: string  # {{{1
                ): void =
    self.xml.add(TagRepeat0(kind: kind, data: data))


proc render_repeat_tag_start(self: TagRepeat, vars: RepeatVars  # {{{1
                             ): tuple[f: bool, d: string] =
    if self.f_omit_tag:
        return (true, "")

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
        if not self.f_omit_tag:
            tags &= fmt"</{self.elem}>"
        i = iter()
    return (tags, false)


proc parse_tree*(self: var TagRepeat, x: XmlParser  # {{{1
                 ): tuple[d: string, f: bool] =
    var d = ""
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
    of xmlCharData, xmlWhitespace:
        self.parse_push(xmlCharData, x.charData)
    of xmlEntity:
        self.parse_push(xmlCharData, render_entity(x.entityName))
    of xmlCData:
        self.parse_push(xmlCharData, render_cdata(x.charData))
    of xmlComment, xmlSpecial, xmlPI:  # Special/PI was ignored now.
        self.parse_push(xmlCharData, render_comment(x.charData))
    of xmlError:
        stderr.write(x.errorMsg() & "\n")
    return (d, true)


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
