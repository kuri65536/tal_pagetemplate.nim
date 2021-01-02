#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1
import json
import os
import streams
import strformat
import strutils
import system

import ../src/tal_pagetemplate
import ../src/tal_pagetemplate/tal_i18n


proc help_text(): void =
    echo("nimptal [-a vars.json] [-i locale,encoding,domain,path] [xml]")
    quit(1)


var (f_next_is_vars, fname_vars) = (false, "")
var f_next_is_i18n = false
var fname_xml = ""

setup_i18n("en", "latin1", "default",
           joinPath(parentDir(currentSourcePath), "tests/catalog"))
for i in countup(1, paramCount()):
    var arg = paramStr(i).string
    if @["-h", "--help"].contains(arg):
        help_text()
    if f_next_is_vars:
        fname_vars = arg
        f_next_is_vars = false
        continue
    if f_next_is_i18n:
        var seq = arg.split(",")
        if len(seq) == 4:
            setup_i18n(seq[0], seq[1], seq[2], seq[3])
        else:
            help_text()
        continue
    if @["-a", "--var"].contains(arg):
        f_next_is_vars = true
        continue
    if @["-i", "--i18n"].contains(arg):
        f_next_is_i18n = true
        continue
    if len(fname_xml) < 1:
        fname_xml = arg
        continue
    echo(fmt"options: ignored {arg}...")

if len(fname_vars) < 1:
    help_text()

var vars = json.parseFile(fname_vars)
var fp: Stream
if len(fname_xml) > 0:
    fp = newFileStream(fname_xml, fmRead)
else:
    fp = newFileStream(stdin)
var lines = parse_template(fp, fname_xml, vars)
var line = lines()
while not finished(lines):
    stdout.write(line)
    line = lines()

# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap


