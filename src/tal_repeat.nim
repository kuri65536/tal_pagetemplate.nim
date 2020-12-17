#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
type
  RepeatVars* = ref object of RootObj  # {{{1
    n_index*, n_number*: int
    f_even*, f_odd*: bool
    f_start*, f_end*: bool
    letter*, Letter*: string
    roman*, Roman*: string



# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
