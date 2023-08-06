# Package
version       = "0.4.2"
author        = "hamidb80"
description   = "a couchDB client written in Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.0"
requires "macroutils >= 1.2.0"
requires "macroplus >= 0.2.5"

task test, "Runs the test suite":
  exec "nim -d:test r tests/tqueryGen.nim"
  exec "nim -d:test --threads:on r tests/tapi.nim"
  
  exec "nim c -o:./tests/temp.exe tests/queryServerInstance.nim"
  exec "nim -d:test r tests/tqueryServer.nim"
  exec "rm ./tests/temp.exe"

task gendocs, "gen docs":
  exec "nim -d:docs doc src/mycouch/api.nim"
