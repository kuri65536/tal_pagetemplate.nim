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
import streams
import strutils
import strformat
import tables
import typeinfo

when false:
    import tal_expr
else:
    import tal_pagetemplate/tal_expr_json
import tal_pagetemplate/tal_common
import tal_pagetemplate/tal_repeat


proc debg(msg: string): void =
    discard


type
  TagProcess {.size: sizeof(cint).}= enum  # {{{1
    tag_in_replace   # replace whole tag with content or expr.
    tag_in_content   # replace content with expr
    tag_in_repeat    # repeat elements by args.

  TagStack = ref object of RootObj  # {{{1
    elem: string
    attrs: Attrs
    flags: set[TagProcess]
    repeat: TagRepeat


  LocalParser = ref object of RootObj  # {{{1
    fn_expr: proc(expr: string): string
    fn_repeat: proc(name, expr: string): iterator(): RepeatVars
    stacks: seq[TagStack]


proc check(self: set[TagProcess], flags: set[TagProcess]): bool =  # {{{1
    return self * flags != {}


proc check_current(self: LocalParser, flags: set[TagProcess]): bool =  # {{{1
    if len(self.stacks) < 1:
        return false
    return self.stacks[0].flags.check(flags)


proc parse_repeat(self: LocalParser, elem, src: string, attrs: Attrs  # {{{1
                  ): TagRepeat =
    var (name, expr) = ("", "")
    for i in src.strip().split(" "):
        if len(i) < 1:  # remove "a  b" -> "a b"
            continue
        if len(name) < 1:
            name = i
        else:
            expr = expr & " " & i
    if len(expr) > 0:
        expr = expr[1 ..^ 1]  # remove left space.
    # echo fmt"repeat -> {name}-{expr}"
    return initTagRepeat(elem, name, expr, attrs, self.fn_expr, self.fn_repeat)


proc render_attrs(elem, sfx: string, attrs: Attrs): string =  # {{{1
    let format = "<$1>"
    if len(attrs) < 1:
        return format.replace("$1", elem)
    debg(fmt"start_tag: {attrs}")
    var ret = format.replace("$1>", elem)
    for k, v in attrs.pairs():
        if k == "tal:content":
            continue
        if k == "tal:repeat":
            continue
        ret = ret & fmt" {k}=" & "\"" & fmt"{v}" & "\""
    ret = ret & ">" & sfx
    return ret


proc start_tag(self: var LocalParser, tag: var TagStack): string =  # {{{1
    debg(fmt"start_tag: {tag.attrs}")
    var attrs = tag.attrs
    if tag.flags.check({tag_in_replace, tag_in_content}):
        return ""  # in replace or in content
    if len(attrs) < 1:
        return render_attrs(tag.elem, "", tag.attrs)

    # TODO(shimoda): parse orders, fit to official
    if attrs.hasKey("tal:repeat"):
        var tmp = attrs
        tmp.del("tal:repeat")
        tag.flags.incl(tag_in_repeat)
        tag.repeat = self.parse_repeat(tag.elem, attrs["tal:repeat"], attrs)
        return ""

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
        if tal_omit_tag_is_enabled(expr):
            self.stacks[0].flags.incl(tag_in_replace)
            return ""

    return render_attrs(tag.elem, sfx, tag.attrs)


proc end_tag(self: var LocalParser, name: string): string =  # {{{1
    if self.check_current({tag_in_replace}):
        return ""
    var ret = "</" & name & ">"
    return ret


proc data(self: var LocalParser, content: string): string =  # {{{1
    if self.check_current({tag_in_replace, tag_in_content}):
        return ""
    return content


proc through(self: var LocalParser, src: string): string =  # {{{1
    return src


proc parse_tag(self: var LocalParser, name: string, f_open: bool  # {{{1
               ): string =
    if self.check_current({tag_in_replace, tag_in_content}):
        return ""

    var stack = TagStack(elem: name, repeat: nil)
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


proc parse_tree_in_repeat(self: var LocalParser, x: XmlParser  # {{{1
                          ): tuple[d: string, f: bool] =
    if not self.check_current({tag_in_repeat}):
        return ("", false)
    var stack = self.stacks[0]
    var (d, f) = stack.repeat.parse_tree(x)
    if f:
        return (d, true)
    # finish a repeat tag
    self.stacks.delete(0)
    # TODO(shimoda): nested repeat.
    return (d, true)


proc parse_tree(src: Stream, filename: string,  # {{{1
                fn_expr: proc(expr: string): string,
                fn_repeat: proc(name, expr: string): iterator(): RepeatVars
                ): iterator(): string =
    iterator ret(): string =
        var parser = LocalParser(fn_expr: fn_expr,
                                 fn_repeat: fn_repeat)
        var x: XmlParser
        open(x, src, "")
        defer: x.close()

        while true:
            x.next()
            var (d, f) = parser.parse_tree_in_repeat(x)
            if len(d) > 0:
                yield d
            if f:
                continue
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
                     ): iterator(): string =
    var vars_tmp = vars
    var vars_tal = TalVars(root: vars_tmp)

    proc parser_json(expr: string): string =
        return vars_tal.parse_expr(expr)

    proc parser_json_repeat(name, expr: string): iterator(): RepeatVars =
        iterator ret(): RepeatVars =
            for i in vars_tal.parse_repeat_seq(name, expr):
                yield i
        return ret

    return parse_tree(src, filename, parser_json, parser_json_repeat)


proc parse_template*(src: Stream, filename: string, vars: any  # {{{1
                     ): iterator(): string =  # {{{1
    proc parser_typeinfo(expr: string, vars: TalVars): string =
        return expr

    return parse_tree(src, filename, parser_typeinfo)


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
