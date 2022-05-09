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
import typeinfo
import xmltree

import tal_i18n


type
  Attrs* = OrderedTable[string, string]  # {{{1

  TagProcess* {.size: sizeof(cint).}= enum  # {{{1
    tag_in_attributes = "tal:attributes"
    tag_in_replace   # replace whole tag with content or expr.
    tag_in_content   # replace content with expr
    tag_in_i18n = "i18n:translate"
    tag_in_i18n_attrs = "i18n:attributes"
    tag_in_repeat    # repeat elements by args.
    tag_in_omit_tag  # tal:omit-tag
    tag_in_notals    # otherwise

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
    name*, expr_str*: string
    attrs*: Attrs
    f_omit_tag*: bool
    exprs*: TalExpr
    xml*: seq[TagRepeat0]
    current*: RepeatStatus

  TagStack* = ref object of RootObj  # {{{1
    elem*: string
    attrs*: Attrs
    flags*: set[TagProcess]
    repeat*: TagRepeat

  TalExpr* = ref object of RootObj  # {{{1
    expr_eval*: proc(expr_str: string): string
    repeat*: proc(path, name, expr_str: string): iterator(): RepeatVars
    defvars*: proc(expr_str, path: string): void
    levvars*: proc(path: string): void

    stacks_i18n*: seq[tuple[path, domain: string]]

  TalVars* = ref object of RootObj  # {{{1
    root_runtime*: Table[string, tuple[path: string, obj: Any]]
    root*: Table[string, tuple[path: string, obj: JsonNode]]
    f_json*: bool


proc newAttrs*(): Attrs =  # {{{1
    return initOrderedTable[string, string]()


proc debg*(msg: string): void =  # {{{1
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


proc initRepeatVars*(n, max: int): RepeatVars =  # {{{1
    var ret = RepeatVars(
        n_index: n, n_number: n + 1, n_length: max,
        f_even: (n mod 2) == 0, f_start: n == 0,
        f_odd: (n mod 2) == 1, f_end: n == max - 1,
        letter: tal_repeat_letters(n),
        roman: tal_repeat_romans(n + 1),
        )
    ret.Letter = ret.letter.toUpper()
    ret.Roman = ret.roman.toUpper()
    return ret


proc tales_bool_expr*(src: string): bool =  # {{{1
    let src = src.strip()
    if src == "true":
        return true
    if src == "false":
        return false
    if len(src) < 1:
        return false      # met 3-1: an empty string
    if src == "null":
        return false     # met 6: all other values are implementation-dependent

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

    let seq = src.replace(" ", "")
    debg(fmt"tal-bool: {src}-{seq}")
    if seq == "{}" or seq == "[]" or seq == "()":
        return false      # met 3-2: other empty sequences.
    # ??? met 4: a non-empty string or other sequence is `true`.
    return true


proc tales_split_path*(src: string  # {{{1
                       ): tuple[ans: JsonNode, parts: seq[string]] =
    var tmp = ""
    if len(src) < 1:
        return (newJNull(), @[])
    tmp = src.strip()
    try:
        var n = newJInt(parseInt(tmp))
        return (n, @[])
    except ValueError:
        discard
    try:
        var n = newJFloat(parseFloat(tmp))
        return (n, @[])
    except ValueError:
        discard

    var parts = src.split("/")
    return (newJNull(), parts)


proc tal_parse_content(self: TalExpr, src: string): string =  # {{{1
    var src = src.strip()
    var f_escape = true
    if src.startsWith("text "):
        src = src[5 ..^ 1]
    elif src.startsWith("structure "):
        f_escape = false
        src = src[10 ..^ 1]

    var ret = self.expr_eval(src)
    if f_escape:
        ret = xmltree.escape(ret)
    return ret


iterator tal_parse_multi_statements*(src: string): string =  # {{{1
    var (expr_str, f_prev_delim) = ("", false)
    for ch in src:
        if ch == ';':
            if f_prev_delim:
                expr_str &= $ch
                f_prev_delim = false  # escaped by doubled ';'
            else:
                f_prev_delim = true
        elif f_prev_delim:
            debg("tal_parse_multi_statements: " & expr_str)
            yield expr_str
            expr_str = $ch
            f_prev_delim = false
        else:
            expr_str &= $ch
    if len(expr_str) > 0:
        debg("tal_parse_multi_statements: " & expr_str)
        yield expr_str


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
        return format.replace("$1", elem) & sfx
    var replaces = newAttrs()
    var attrs = attrs

    proc render(attr, expr_str: string, replaces: var Attrs,
                cb: proc(src: string): string) =
        debg(fmt"tal:attributes -> {expr_str}")
        for src in tal_parse_multi_statements(expr_str):
            debg(fmt"tal:attributes -> {src}")
            # TODO(shimoda): escape `;` by doubling.
            var src = src.strip()
            var seq = src.split(" ")
            if len(seq) < 2:
                continue  # TODO(shimoda): error handling...
            var name = seq[0]  # TODO(shimoda): namespace...
            var expression = join(seq[1 ..^ 1], " ")
            expression = expression.strip()
            expression = cb(expression)
            replaces[name] = expression
        debg(fmt"tal:attributes -> replaces: {replaces}")

    if true:
      let attr = $tag_in_attributes
      if attrs.hasKey(attr):
        render(attr, attrs[attr], replaces, proc(src: string): string =
            return self.expr_eval(src))
        attrs.del(attr)

    if true:
      let attr = $tag_in_i18n_attrs
      if attrs.hasKey(attr):
        render(attr, attrs[attr], replaces, proc(src: string): string =
            return render_i18n_trans(src))
        attrs.del(attr)

    debg(fmt"start_tag: {attrs}")
    var ret = format.replace("$1>", elem)
    for k, v in attrs.pairs():
        # tal:*** are removed from `Attrs` before entering to this function.
        # TODO(shimoda): remove `continue` by removing items from `Attrs`.
        if k == "tal:content":
            continue
        if k == "tal:repeat":
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
                      attrs: var Attrs): tuple[n: set[TagProcess], d: string] =
    var ret = {tag_in_notals}
    if attrs.hasKey("tal:define"):
        let expr_str = attrs["tal:define"]
        attrs.del("tal:define")
        self.defvars(expr_str, path)  # TODO(shimoda): path in repeat

    if true:
      let attr = "i18n:domain"
      if attrs.hasKey(attr):
        let domain = attrs[attr]
        attrs.del(attr)
        enter_i18n_domain(self.stacks_i18n, path, domain)

    if true:
      let attr = "tal:omit-tag"
      if attrs.hasKey(attr):
        var expr_str = attrs[attr]
        attrs.del(attr)
        if len(expr_str) < 1:
            ret.incl(tag_in_omit_tag)
        else:
            expr_str = self.expr_eval(expr_str)
            if not tales_bool_expr(expr_str):
                ret.incl(tag_in_omit_tag)

    if true:
      let attr = "tal:condition"
      if attrs.hasKey(attr):
        let expr_str = self.expr_eval(attrs[attr])
        attrs.del(attr)
        if not tales_bool_expr(expr_str):
            return ({tag_in_replace}, "")

    if attrs.hasKey("tal:replace"):
        var expr_str = attrs["tal:replace"]
        return ({tag_in_replace}, self.expr_eval(expr_str))

    if true:
      let attr = "tal:content"
      if attrs.hasKey(attr):
        let expr_str = self.tal_parse_content(attrs[attr])
        ret.incl(tag_in_content)
        if ret.contains(tag_in_omit_tag):
            return (ret, expr_str)
        return (ret, self.render_attrs(name, expr_str, attrs))

    if true:
      let attr = $tag_in_i18n
      if attrs.hasKey(attr):
        let txt = render_i18n_trans(attrs[attr])
        attrs.del(attr)
        ret.incl(tag_in_content)
        if ret.contains(tag_in_omit_tag):
            return (ret, txt)
        return (ret, self.render_attrs(name, txt, attrs))

    if ret.contains(tag_in_omit_tag):
        return (ret, "")
    return (ret, self.render_attrs(name, "", attrs))


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
