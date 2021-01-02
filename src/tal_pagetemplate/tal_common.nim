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

import tal_i18n


type
  Attrs* = OrderedTable[string, string]  # {{{1

  TagProcess* {.size: sizeof(cint).}= enum  # {{{1
    tag_in_replace   # replace whole tag with content or expr.
    tag_in_content   # replace content with expr
    tag_in_i18n = "i18n:translate"
    tag_in_repeat    # repeat elements by args.
    tag_in_omit_tag  # tal:omit-tag
    tag_in_notal     # otherwise

  RepeatStatus* = ref object of RootObj  # {{{1
    element_ignore*: string

  RepeatVars* = ref object of RootObj  # {{{1
    n_index*, n_number*, n_length*: int
    f_even*, f_odd*: bool
    f_start*, f_end*: bool
    letter*, Letter*: string
    roman*, Roman*: string

  TagRepeat0* = ref object of RootObj  # {{{1
    kind*: XmlEventKind
    data*: string

  TagRepeat* = ref object of RootObj  # {{{1
    elem*, elem_prev*, path*: string
    name*, expr*: string
    attrs*: Attrs
    exprs*: TalExpr
    xml*: seq[TagRepeat0]
    current*: RepeatStatus

  TagStack* = ref object of RootObj  # {{{1
    elem*: string
    attrs*: Attrs
    flags*: set[TagProcess]
    repeat*: TagRepeat

  TalExpr* = ref object of RootObj  # {{{1
    expr*: proc(expr: string): string
    repeat*: proc(path, name, expr: string): iterator(): RepeatVars
    defvars*: proc(expr, path: string): void
    levvars*: proc(path: string): void

    stacks_i18n*: seq[tuple[path, domain: string]]

  TalVars* = ref object of RootObj  # {{{1
    when true:
        root*: Table[string, tuple[path: string, obj: JsonNode]]
    else:
        root*: any


proc newAttrs*(): Attrs =  # {{{1
    return initOrderedTable[string, string]()


proc debg*(msg: string): void =  # {{{1
    discard


proc tales_bool_expr*(src: string): bool =  # {{{1
    let src = src.strip()
    try:
        var n = parseInt(src)
        if n != 0:
            return true   # met 2: pos and neg numbers are `true`
        return false      # met 1: the number 0 is `false`
    except ValueError:
        discard

    if src == "nothing":
        return false      # met 5: a non-value is `false`
    if src == "void":
        return false      # met 5: ...
    if src == "None":
        return false      # met 5: ...
    if src == "Nil":
        return false      # met 5: ...
    if src == "NULL":
        return false      # met 5: ...
    if src == "nil":
        return false      # met 6: implementation-dependent
    # ??? met 5: etc

    if len(src) < 1:
        return false      # met 3-1: an empty string
    let seq = src.replace(" ", "")
    if src == "{}" or src == "[]" or src == "()":
        return false      # met 3-2: other empty sequences.
    # ??? met 4: a non-empty string or other sequence is `true`.
    # ??? met 6: all other values are implementation-dependent
    return true


proc render_endtag*(src: string): string =  # {{{1
    return fmt"</{src}>"


proc render_cdata*(src: string): string =  # {{{1
    return fmt"<![CDATA[{src}]]>"


proc render_comment*(src: string): string =  # {{{1
    return fmt"<!--{src}-->"


proc render_entity*(src: string): string =  # {{{1
    return fmt"&{src};"


proc render_pi*(name, rest: string): string =  # {{{1
    return fmt"<? {name} ## {rest} ?>"


proc render_special*(src: string): string =  # {{{1
    return fmt"<!{src}>"


proc xml_path*(src: seq[TagStack]): string =  # {{{1
    var ret = ""
    for i in src:
        ret = i.elem & "-" & ret
    return ret


proc render_attrs*(self: TalExpr, elem, sfx: string, attrs: Attrs): string =  # {{{1
    let format = "<$1>"
    if len(attrs) < 1:
        return format.replace("$1", elem)
    var replaces = newAttrs()
    if attrs.hasKey("tal:attributes"):
        var expr = attrs["tal:attributes"]
        debg(fmt"tal:attributes -> {expr}")
        for src in expr.split(";"):
            debg(fmt"tal:attributes -> {src}")
            # TODO(shimoda): escape `;` by doubling.
            var src = src.strip()
            var seq = src.split(" ")
            if len(seq) < 2:
                continue  # TODO(shimoda): error handling...
            var name = seq[0]  # TODO(shimoda): namespace...
            var expression = join(seq[1 ..^ 1], " ")
            expression = expression.strip()
            expression = self.expr(expression)
            replaces.add(name, expression)
        debg(fmt"tal:attributes -> replaces: {replaces}")

    debg(fmt"start_tag: {attrs}")
    var ret = format.replace("$1>", elem)
    for k, v in attrs.pairs():
        # TODO(shimoda): remove `continue` by removing items from `Attrs`.
        if k == "tal:define":
            continue
        if k == "tal:content":
            continue
        if k == $tag_in_i18n:
            continue
        if k == "tal:repeat":
            continue
        if k == "tal:attributes":
            continue
        var v = v
        if replaces.hasKey(k):
            v = replaces[k]
            debg(fmt"tal:attributes: replace: {k}->{v}")
            replaces.del(k)
        ret &= fmt" {k}=" & "\"" & v & "\""
    for k, v in replaces.pairs():
        debg(fmt"tal:attributes: insert: {k}->{v}")
        ret &= fmt" {k}=" & "\"" & v & "\""
    ret = ret & ">" & sfx
    return ret


proc render_starttag*(self: TalExpr, path, name: string,  # {{{1
                      attrs: var Attrs): tuple[n: TagProcess, d: string] =
    if attrs.hasKey("tal:define"):
        var expr = attrs["tal:define"]
        attrs.del("tal:define")
        self.defvars(expr, path)  # TODO(shimoda): path in repeat

    if true:
      let attr = "i18n:domain"
      if attrs.hasKey(attr):
        var expr = attrs[attr]
        attrs.del(attr)
        enter_i18n_domain(self.stacks_i18n, path, expr)

    if true:
      let attr = "tal:condition"
      if attrs.hasKey(attr):
        var expr = self.expr(attrs[attr])
        attrs.del(attr)
        if not tales_bool_expr(expr):
            return (tag_in_replace, "")

    if attrs.hasKey("tal:replace"):
        var expr = attrs["tal:replace"]
        return (tag_in_replace, self.expr(expr))

    if attrs.hasKey("tal:content"):
        var expr = attrs["tal:content"]
        expr = self.expr(expr)
        return (tag_in_content, self.render_attrs(name, expr, attrs))

    if attrs.hasKey($tag_in_i18n):
        var expr = attrs[$tag_in_i18n]
        expr = render_i18n_trans(expr)
        return (tag_in_content, self.render_attrs(name, expr, attrs))

    if true:
      let attr = "tal:omit-tag"
      if attrs.hasKey(attr):
        var expr = attrs[attr]
        attrs.del(attr)
        if len(expr) < 1:
            return (tag_in_omit_tag, "")
        expr = self.expr(expr)
        if not tales_bool_expr(expr):
            return (tag_in_omit_tag, "")

    return (tag_in_notal, self.render_attrs(name, "", attrs))


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
