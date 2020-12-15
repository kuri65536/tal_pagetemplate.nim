#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import json
import parsexml
import streams
import strutils
import strformat
import tables
import typeinfo


type
  Attrs = Table[string, string]

  LocalParser = ref object of RootObj  # {{{1
    fn_expr: proc(expr: string): string
    elem: string
    stack_attrs: seq[Attrs]
    stack_flags: seq[int]


proc is_true(src: string): bool =  # {{{1
    # TODO(shimoda): check official TAL docs.
    var i = src.strip().toLower()
    if src == "yes":
        return true
    if src == "true":
        return true
    return false


proc start_tag(self: var LocalParser, name: string,  # {{{1
               attrs: Attrs): string =
    let fmt = "<$1>"
    if len(attrs) < 1:
        return fmt.replace("$1", name)
    var cur_flags = self.stack_flags[0]
    if (cur_flags and 1) != 0:
        return ""  # in replace
    if (cur_flags and 2) != 0:
        return ""  # in content

    # TODO(shimoda): parse order to official
    if attrs.hasKey("tal:replace"):
        self.stack_flags.insert(0, 1)
        var expr = attrs["tal:replace"]
        return self.fn_expr(expr)
    if attrs.hasKey("tal:omit-tag"):
        var expr = attrs["tal:omit-tag"]
        expr = self.fn_expr(expr)
        if expr == "" or is_true(expr):
            self.stack_flags.insert(0, 1)
            return ""

    var tag = fmt.replace("$1>", name)
    var flags = 0
    for k, v in attrs.pairs():
        if k == "tal:content":
            flags = flags or 2
            continue
        tag = tag & fmt" {k}=" & "\"" & fmt"{v}" & "\""
    return tag


proc end_tag(self: var LocalParser, name: string): string =  # {{{1
    return "</" & name & ">"


proc data(self: var LocalParser, content: string): string =  # {{{1
    return content


proc through(self: var LocalParser, src: string): string =  # {{{1
    return src


proc parse_tag(self: var LocalParser, name: string, f_open: bool  # {{{1
               ): string =
    self.elem = name
    self.stack_attrs.insert(initTable[string, string](), 0)
    if not f_open:
        return self.start_tag(name, self.stack_attrs[0])
    return ""  # wait for close


proc parse_tagclose(self: var LocalParser): string =  # {{{1
    var attrs = self.stack_attrs[^1]
    return self.start_tag(self.elem, attrs)


proc parse_attr(self: var LocalParser, name, value: string): string =  # {{{1
    var attrs = self.stack_attrs[^1]
    attrs.add(name, value)
    return ""  # wait for close


proc parse_tagend(self: var LocalParser, name: string): string =  # {{{1
    var ret = self.end_tag(name)
    self.stack_attrs.delete(0)
    return ret


proc parse_tree(src: Stream, filename: string,  # {{{1
                fn_expr: proc(expr: string): string
                ): iterator(): string =  # {{{1
    iterator ret(): string =
        var parser = LocalParser(fn_expr: fn_expr)
        var x: XmlParser
        open(x, src, "")
        defer: x.close()

        while true:
            var d = ""
            x.next()
            case x.kind
            of xmlElementStart: d = parser.parse_tag(x.elementName, false)
            of xmlElementOpen:  d = parser.parse_tag(x.elementName, true)
            of xmlAttribute:    d = parser.parse_attr(x.attrKey, x.attrValue)
            of xmlElementClose: d = parser.parse_tagclose()
            of xmlElementEnd:   d = parser.parse_tagend(x.elementName)
            of xmlCharData:     d = parser.data(x.charData)
            of xmlWhitespace:   d = parser.data(x.charData)
            of xmlCData:        d = parser.data(x.charData)
            of xmlSpecial:      d = parser.data(x.charData)
            of xmlEntity:       d = parser.data(x.entityName)
            of xmlComment:      d = parser.through(x.charData)  # "<!-- $1 -->"
            of xmlPI:
                d = parser.through("<? $1 ## $2 ?>" % [x.piName, x.piRest])
            of xmlError:        echo(x.errorMsg())
            of xmlEof:
                break # end of file reached

            if len(d) < 1:
                continue
            yield d
    return ret


proc parse_template*(src: Stream, filename: string, vars: JsonNode  # {{{1
                     ): iterator(): string =  # {{{1
    proc parser_json(expr: string): string =
        return expr

    return parse_tree(src, filename, parser_json)


proc parse_template*(src: Stream, filename: string, vars: any  # {{{1
                     ): iterator(): string =  # {{{1
    proc parser_typeinfo(expr: string): string =
        return expr

    return parse_tree(src, filename, parser_typeinfo)


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
