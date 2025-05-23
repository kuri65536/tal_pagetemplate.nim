TAL page template in nim project
===============================================================================
This is a yet another version of TAL page template program with
nim language.

TAL or TALE are familier as Zope PTAL, PHPTAL and etc.

This repository goal is to make up my project compatiblity in python and nim,
not enable to implement the all TAL features.

but I refer the behavior of TAL in official TAL document::

    https://pagetemplates.readthedocs.io/en/latest/tal.html


![test](https://github.com/kuri65536/tal_pagetemplate.nim/actions/workflows/main.yml/badge.svg)



Requirements
-----------------------------------------
- nim (>= 0.19.4)
- nim-i18n (>= 0.1.2)
- xml of PTAL
- json data or nim objects for variables


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
### test xml::

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


### variables
see test1.nim or test2.nim, in test2.nim:

```
type
  TestObj2 = object
    f: float
    f32: float32
    f64: float64
    ch: char
    str: string
    b: bool


test "T4-1-3: use nim rtti - f, f32-64":
    var tmp = TestObj2(f: 1.0, f32: 2.0, f64: 3.0)
    var v = toAny(tmp)
    var fp = newStringStream("<p tal:replace=\"f\"> </p>," &
                             "<p tal:replace=\"f32\"> </p>," &
                             "<p tal:replace=\"f64\"> </p>,")
    check parse_all2(fp, v) == "1.0,2.0,3.0,"
```


Release
-----------------------------------------
| version | description |
|:-------:|:---|
| 0.3.1   | fix behavior for invalid values, enable enums in rtti |
| 0.3.0   | add i18n:attributes |
| 0.1.0   | 1st version |


Donations
---------------------
If you are feel to nice for this software, please donate to

[![img-bitcoin]][lnk-bitcoin]
&nbsp;&nbsp;or&nbsp;&nbsp;
[![img-etherium]][lnk-bitcoin]

- [bitcoin:39Qx9Nffad7UZVbcLpVpVanvdZEQUanEXd][lnk-bitcoin]
- [ethereum:0x9d03b1a8264023c3ad8090b8fc2b75b1ba2b3f0f][lnk-bitcoin]
- or [liberapay](https://liberapay.com/kuri65536) .

[lnk-bitcoin]:  https://kuri65536.bitbucket.io/donation.html?message=thank-for-tal_pagetemplate
[img-bitcoin]:  https://github.com/user-attachments/assets/abce4347-bcb3-42c6-a9e8-1cd12f1bd4a5
[img-etherium]: https://github.com/user-attachments/assets/d1bdb9a8-9c6f-4e74-bc19-0d0bfa041eb2

