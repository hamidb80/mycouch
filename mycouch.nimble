# Package
version       = "0.2.2"
author        = "hamidb80"
description   = "a couchDB client written in Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.4.8"
requires "macroutils >= 1.2.0"
requires "macroplus"
requires "https://github.com/hamidb80/coverage"

task test, "Runs the test suite":
  exec "nim -d:test r tests/tqueryGen.nim"
  exec "nim -d:test r tests/tapi.nim"

task gendocs, "gen docs":
  exec "nim -d:docs doc src/mycouch/api.nim"