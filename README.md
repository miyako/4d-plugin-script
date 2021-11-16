![version](https://img.shields.io/badge/version-16%2B-8331AE)
![platform](https://img.shields.io/static/v1?label=platform&message=win-32%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-script)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-script/total)

# 4d-plugin-script
4D implementation of IActiveScript

## Syntax

```
result:=Script parse (engine;script)
```

Parameter|Type|Description
------------|------------|----
engine|TEXT|name or extension that specifies the language
script|TEXT|code
result|TEXT|value

### Examples

```
$result:=Script parse ("JScript";"Date()")
$result:=Script parse (".js";"1+2")

$result:=Script parse ("vbscript";"Now")
$result:=Script parse (".vbs";"Now")

$result:=Script parse ("JScript";"var a;a = 1;a++;a;")
$result:=Script parse ("vbscript";"4*atn(1.0)")
```
