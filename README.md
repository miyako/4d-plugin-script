# 4d-plugin-script
4D implementation of IActiveScript


### Examples

```
$result:=Script parse ("JScript";"Date()")
$result:=Script parse (".js";"1+2 ")

$result:=Script parse ("vbscript";"Now")
$result:=Script parse (".vbs";"Now")

$result:=Script parse ("JScript";"var a;a = 1;a++;a;")
$result:=Script parse ("vbscript";"4*atn(1.0)")
```
