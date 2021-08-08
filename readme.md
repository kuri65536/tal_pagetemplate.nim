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
- nim-i18n (>= 0.1.2)
- xml of PTAL
- json for variables


### In Debian buster
```shell
$ sudo apt intall nim
```


How to use
-----------------------------------------
use from your nim project, install from nimble and import this.

```shell
$ nimble install https://github.com/kuri65536/tal_pagetemplate.nim
```

```nim
import tal_pagetemplate
```


also can use from command line,

```shell
$ nim c -o=nimptal tests/cmdline.nim
$ ./nimptal test.xml
...output...
```


TODO
-----------------------------------------
- parse single close tags: `<br />`
- re-write tal:repeat and its nesting.
- metal features (low priority, it is too complex for me.)
- tal expressions: `default`
- tal expressions: `attrs`
- tal expressions: `CONTEXTS`

### no plan to implement
- `tal:on-error`
- tal expressions: `python` - too complex...
- tal expressions: `nocall` - no dynamic evaluations.
- namespace in variables.


Development Environment
-----------------------------------------

| term | description   |
|:----:|:--------------|
| OS   | Debian on Android 10 |
| lang | nim |



Reference
-----------------------------------------
- https://pagetemplates.readthedocs.io/en/latest/tal.html


License
-----------------------------------------
see the top of source code, it is MPL2.0.


sample outputs
-----------------------------------------
test xml::

```xml
<!DOCTYPE HTML>
<html>
<head>
</head>
<body>
  <p tal:content="content">
  </p>
  <br />
  <input type="aaa" />
  <!-- this is comment -->
</body>
</html>
```

its output::

```xml
<!DOCTYPE HTML>
<html>
<head>
</head>
<body>
  <p>1</p>
  <br></br>
  <input type="aaa"></input>
  <!-- this is comment -->
</body>
</html>
```


Release
-----------------------------------------
| version | description |
|:-------:|:---|
| 0.3.0   | add i18n:attributes |
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
