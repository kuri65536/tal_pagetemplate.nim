#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#  # import {{{1


when true:  # TODO(shimoda): i18n macro on/off
  import i18n

  var i18n_domain_default = "default"

  proc setup_i18n*(locale, encoding, domain, path: string): void =  #  # {{{1
    bindTextDomain(domain, path)
    i18n.setTextLocale(locale, encoding)
    i18n.setTextDomain(domain)
    i18n_domain_default = domain


  proc enter_i18n_domain*(stacks: var seq[tuple[path, domain: string]],  # {{{1
                          path, domain: string): void =
    stacks.insert((path, domain), 0)
    echo(path, ":", domain)
    i18n.setTextDomain(domain)


  proc leave_i18n_domain*(stacks: var seq[tuple[path, domain: string]],  # {{{1
                          path: string): void =
    if len(stacks) < 1:
        return
    if stacks[0].path != path:
        return
    stacks.delete(0)
    var domain = i18n_domain_default
    if len(stacks) > 0:
        domain = stacks[0].domain
    i18n.setTextDomain(domain)


  proc render_i18n_trans*(src: string): string =  # {{{1
    return gettext(src)


else:  # dummies not use nim-i18n  # {{{1
  discard


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
