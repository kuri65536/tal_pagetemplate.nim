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


proc debg(msg: string): void =
    discard


type
  Attrs = Table[string, string]

  TagProcess {.size: sizeof(cint).}= enum
    tag_in_replace   # replace whole tag with content or expr.
    tag_in_content   # replace content with expr

  TagStack = ref object of RootObj  # {{{1
    elem: string
    attrs: Attrs
    flags: set[TagProcess]

  LocalParser = ref object of RootObj  # {{{1
    fn_expr: proc(expr: string): string
    stacks: seq[TagStack]


proc is_true(src: string): bool =  # {{{1
    # TODO(shimoda): check official TAL docs.
    var i = src.strip().toLower()
    if src == "yes":
        return true
    if src == "true":
        return true
    return false


proc start_tag(self: var LocalParser, tag: var TagStack): string =  # {{{1
    let fmt = "<$1>"
    debg(fmt"start_tag: {tag.attrs}")
    var attrs = tag.attrs
    if tag.flags.contains(tag_in_replace):
        return ""  # in replace
    if tag.flags.contains(tag_in_content):
        return ""  # in content
    if len(attrs) < 1:
        return fmt.replace("$1", tag.elem)

    # TODO(shimoda): parse orders, fit to official
    var sfx = ""
    if attrs.hasKey("tal:replace"):
        tag.flags.incl(tag_in_replace)
        var expr = attrs["tal:replace"]
        return self.fn_expr(expr)
    if attrs.hasKey("tal:content"):
        tag.flags.incl(tag_in_content)
        var expr = attrs["tal:content"]
        sfx = self.fn_expr(expr)
    if attrs.hasKey("tal:omit-tag"):
        var expr = attrs["tal:omit-tag"]
        expr = self.fn_expr(expr)
        if expr == "" or is_true(expr):
            self.stacks[0].flags.incl(tag_in_replace)
            return ""

    debg(fmt"start_tag: {attrs}")
    var tag = fmt.replace("$1>", tag.elem)
    var flags = 0
    for k, v in attrs.pairs():
        if k == "tal:content":
            flags = flags or 2
            continue
        tag = tag & fmt" {k}=" & "\"" & fmt"{v}" & "\""
    return tag & ">" & sfx


proc end_tag(self: var LocalParser, name: string): string =  # {{{1
    if len(self.stacks) < 1:
        discard
    elif self.stacks[0].flags.contains(tag_in_replace):
        return ""
    return "</" & name & ">"


proc data(self: var LocalParser, content: string): string =  # {{{1
    if len(self.stacks) < 1:
        discard
    if self.stacks[0].flags * {tag_in_replace, tag_in_content} != {}:
        return ""
    return content


proc through(self: var LocalParser, src: string): string =  # {{{1
    return src


proc parse_tag(self: var LocalParser, name: string, f_open: bool  # {{{1
               ): string =
    if len(self.stacks) < 1:
        discard
    elif self.stacks[0].flags * {tag_in_replace, tag_in_content} != {}:
        return ""

    var stack = TagStack(elem: name)
    var new_flags: set[TagProcess]
    if len(self.stacks) > 0:
        var prev_flags = self.stacks[0].flags
        if prev_flags.contains(tag_in_replace):
            new_flags = {}
    stack.flags = {}
    stack.attrs = initTable[string, string]()
    self.stacks.insert(stack, 0)
    if not f_open:
        return self.start_tag(self.stacks[0])
    return ""  # wait for close


proc parse_tagclose(self: var LocalParser): string =  # {{{1
    debg(fmt"found '>' for {self.stacks[0].elem}")
    return self.start_tag(self.stacks[0])


proc parse_attr(self: var LocalParser, name, value: string): string =  # {{{1
    self.stacks[0].attrs.add(name, value)
    #[
    var attrs = self.stack_attrs[0]
    attrs.add(name, value)
    echo(fmt"found attr {attrs}")
    ]#
    debg(fmt"found attr {self.stacks[0].attrs}")
    return ""  # wait for close


proc parse_tagend(self: var LocalParser, name: string): string =  # {{{1
    var ret = self.end_tag(name)
    if len(self.stacks) < 1:
        discard
    elif self.stacks[0].elem == name:
        self.stacks.delete(0)
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
