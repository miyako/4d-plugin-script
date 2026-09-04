//%attributes = {}
$result:=Script parse("JScript.dll"; "var a;a = 1;a++;a;")


$result:=Script parse("JScript"; "var a;a = 1;a++;a;")

$result:=Script parse("vbscript"; "4*atn(1.0)")

$result:=Script parse("JScript"; "Date()")
$result:=Script parse(".js"; "1+2 ")

$result:=Script parse("vbscript"; "Now")
$result:=Script parse(".vbs"; "Now")
