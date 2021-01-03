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

import tal_pagetemplate/tal_common
import tal_pagetemplate/tal_expr
import tal_pagetemplate/tal_repeat
import tal_pagetemplate/tal_i18n

import tal_pagetemplate/tal_expr_runtime
import tal_pagetemplate/tal_expr_json


type
  LocalParser = ref object of RootObj  # {{{1
    exprs: TalExpr
    stacks: seq[TagStack]
    curr_pos, last_pos: tuple[line, col: int]


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
    debg(fmt"repeat -> {name}-{expr}")
    var path = self.stacks.xml_path()
    return initTagRepeat(elem, path, name, expr, attrs, self.exprs)


proc start_tag(self: var LocalParser, tag: var TagStack): string =  # {{{1
    debg(fmt"start_tag: {tag.attrs}")
    var attrs = tag.attrs
    if tag.flags.check({tag_in_replace, tag_in_content}):
        return ""  # in replace or in content
    if len(attrs) < 1:
        return self.exprs.render_attrs(tag.elem, "", tag.attrs)

    # TODO(shimoda): parse orders, fit to official
    var (n, d) = self.exprs.render_starttag(
            self.stacks.xml_path(), tag.elem, attrs)

    if n.contains(tag_in_omit_tag):
        tag.flags.incl(tag_in_omit_tag)

    if attrs.hasKey("tal:repeat"):
        var tmp = attrs
        tmp.del("tal:repeat")
        tag.flags.incl(tag_in_repeat)
        tag.repeat = self.parse_repeat(tag.elem, attrs["tal:repeat"], attrs)
        if n.contains(tag_in_omit_tag):
            tag.repeat.f_omit_tag = true
        return ""

    if n.contains(tag_in_replace):
        tag.flags.incl(n)
        return d
    if n.contains(tag_in_content):
        tag.flags.incl(n)
        return d
    return d


proc end_tag(self: var LocalParser, name: string): string =  # {{{1
    if self.check_current({tag_in_replace, tag_in_omit_tag}):
        return ""
    var ret = render_endtag(name)

    var path = xml_path(self.stacks)  # remove local vars
    debg("leavevars: " & path)
    self.exprs.levvars(path)
    leave_i18n_domain(self.exprs.stacks_i18n, path)
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
    stack.attrs = initOrderedTable[string, string]()
    self.stacks.insert(stack, 0)
    if not f_open:
        return self.start_tag(self.stacks[0])
    return ""  # wait for close


proc parse_tagclose(self: var LocalParser): string =  # {{{1
    debg(fmt"found '>' for {self.stacks[0].elem}")
    return self.start_tag(self.stacks[0])


proc parse_attr(self: var LocalParser, name, value: string): string =  # {{{1
    self.stacks[0].attrs.add(name, value)
    debg(fmt"found attr {self.stacks[0].attrs}")
    return ""  # wait for close


proc parse_tagend(self: var LocalParser, name: string): string =  # {{{1
    var ret = self.end_tag(name)
    if len(self.stacks) < 1:
        discard
    elif self.stacks[0].elem == name:
        self.stacks.delete(0)
    elif self.check_current({tag_in_content}):
        ret = ""
    debg(fmt"</>: {self.curr_pos}-{self.last_pos}")
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
                exprs: TalExpr): iterator(): string =
    iterator ret(): string =
        var parser = LocalParser(exprs: exprs)
        var x: XmlParser
        open(x, src, "", {reportWhitespace, reportComments})
        defer: x.close()

        while true:
            x.next()
            var (d, f) = parser.parse_tree_in_repeat(x)
            if len(d) > 0:
                yield d
            if f:
                continue
            parser.curr_pos = (x.getLine(), x.getColumn())
            case x.kind
            of xmlElementStart: d = parser.parse_tag(x.elementName, false)
            of xmlElementOpen:  d = parser.parse_tag(x.elementName, true)
            of xmlAttribute:    d = parser.parse_attr(x.attrKey, x.attrValue)
            of xmlElementClose: d = parser.parse_tagclose()
            of xmlElementEnd:   d = parser.parse_tagend(x.elementName)
            of xmlCharData:     d = parser.data(x.charData)
            of xmlWhitespace:   d = parser.data(x.charData)
            of xmlCData:        d = parser.through(render_cdata(x.charData))
            of xmlComment:      d = parser.through(render_comment(x.charData))
            of xmlEntity:       d = parser.through(render_entity(x.entityName))
            of xmlPI:         d = parser.through(render_pi(x.piName, x.piRest))
            of xmlSpecial:      d = parser.through(render_special(x.charData))
            of xmlError:        stderr.write(x.errorMsg() & "\n")
            of xmlEof:
                break # end of file reached

            parser.last_pos = parser.curr_pos
            if len(d) < 1:
                continue
            yield d
    return ret


proc parse_template*(src: Stream, filename: string, vars: JsonNode  # {{{1
                     ): iterator(): string =
    var vars_expr: TalExpr
    var vars_tal = TalVars(f_json: true,
            root: initTable[string, tuple[path: string, obj: JsonNode]]())
    for name, fld in vars.getFields():
        vars_tal.root[name] = ("", fld)

    proc parser_json(expr: string): string =
        return vars_tal.tales_parse(expr)

    proc parser_json_repeat(path, name, expr: string): iterator(): RepeatVars =
        iterator ret(): RepeatVars =
            for i in vars_tal.parse_repeat_seq(name, path, expr):
                yield i
        return ret

    proc parser_json_defvars(expr, path: string): void =
        vars_expr.parse_define(vars_tal, expr, path)

    proc parser_json_leavevars(path: string): void =
        vars_tal.leave_define(path)

    vars_expr = TalExpr(expr: parser_json,
                        repeat: parser_json_repeat,
                        defvars: parser_json_defvars,
                        levvars: parser_json_leavevars,
                        stacks_i18n: @[])
    return parse_tree(src, filename, vars_expr)


proc parse_template*(src: Stream, filename: string, vars: Any  # {{{1
                     ): iterator(): string =
    var vars_expr: TalExpr
    var vars_tal = TalVars(f_json: false,
            root_runtime: initTable[string, tuple[path: string, obj: Any]]())
    vars_tal.root_runtime.copy_from(vars)

    proc parser_rtti(expr: string): string =
        return vars_tal.tales_parse(expr)

    proc parser_rtti_repeat(path, name, expr: string): iterator(): RepeatVars =
        iterator ret(): RepeatVars =
            for i in vars_tal.parse_repeat_seq(name, path, expr):
                yield i
        return ret

    proc parser_rtti_defvars(expr, path: string): void =
        vars_expr.parse_define(vars_tal, expr, path)

    proc parser_rtti_leavevars(path: string): void =
        vars_tal.leave_define(path)

    vars_expr = TalExpr(expr: parser_rtti,
                        repeat: parser_rtti_repeat,
                        defvars: parser_rtti_defvars,
                        levvars: parser_rtti_leavevars,
                        stacks_i18n: @[])
    return parse_tree(src, filename, vars_expr)


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
