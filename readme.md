TAL page template in nim project
===============================================================================
This is a yet another version of TAL page template program with
nim language.

TAL or TALE are familier as Zope PTAL, PHPTAL and etc.

This repository goal is to make up my project compatiblity in python and nim,
not enable to implement the all TAL features.

but I refer the behavior of TAL in official TAL document::

    https://pagetemplates.readthedocs.io/en/latest/tal.html


Requirements
-----------------------------------------
- nim (>= 0.19.4)
- xml of PTAL
- json for variables


### In Debian buster
```shell
$ sudo apt intall nim
```


How to use
-----------------------------------------
use for your nim project, install from nimble and import this.

```shell
$ nimble https://github.com/kuri65536/tal_pagetemplate.nim
```

```nim
import tal_pagetemplate
```


TODO
-----------------------------------------
- enable the varibles from nim runtime informations, instead of JSON.
- enable JSON string/ fields.
- escape `;` by doubling
- namespace in variables.
- tal:on-error
- i18n:translate
- i18n:domain
- parse single close tags: `<br />`
- re-write tal:repeat and its nesting.


Development Environment
-----------------------------------------

| term | description   |
|:----:|:--------------|
| OS   | Debian on Android 10 |
| lang | nim |



Reference
-----------------------------------------
- T.B.D.


License
-----------------------------------------
see the top of source code, it is MPL2.0.


sample outputs
-----------------------------------------
test xml::

```xml
```

its output::

```xml
```


Release
-----------------------------------------
| version | description |
|:-------:|:---|
| 0.1.0   | 1st version |


Donations
---------------------
If you are feel to nice for this software, please donation to my

- Bitcoin **| 1FTBAUaVdeGG9EPsGMD5j2SW8QHNc5HzjT |**
- Ether **| 0xd7Dc5cd13BD7636664D6bf0Ee8424CFaF6b2FA8f |**
- or librapay, I'm glad from smaller (about $1) and welcome more :D

<!--
vi: ft=markdown:et:fdm=marker
-->
