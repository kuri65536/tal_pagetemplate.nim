#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
import strutils


type
  RepeatVars* = ref object of RootObj  # {{{1
    n_index*, n_number*, n_length*: int
    f_even*, f_odd*: bool
    f_start*, f_end*: bool
    letter*, Letter*: string
    roman*, Roman*: string

  TalExpr* = ref object of RootObj  # {{{1
    expr*: proc(expr: string): string
    repeat*: proc(name, expr: string): iterator(): RepeatVars
    defvars*: proc(expr: string): void


proc is_true(src: string): bool =  # {{{1
    # TODO(shimoda): check official TAL docs.
    var i = src.strip().toLower()
    if src == "yes":
        return true
    if src == "true":
        return true
    return false


proc tal_omit_tag_is_enabled*(src: string): bool =  # {{{1
    if src == "":
        return true
    if is_true(src):
        return true
    return false

