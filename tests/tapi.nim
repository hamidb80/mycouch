import unittest, httpcore, json, sequtils, strutils, strformat
import coverage
import mycouch/[api, private/exceptions]

func contains(json: JsonNode, keys: openArray[string]): bool =
  for k in keys:
    if k notin json:
      return false
  true

template createClient {.dirty.}=
  let cc = newCouchDBClient()
  discard cc.cookieAuthenticate("admin", "admin")

template testAPI(name, body) {.dirty.}=
  test name:
    try:
      body

    except CouchDBError as e:
      echo fmt"API Error: {e.responseCode}"
      echo "details: ", e.info
      check false
    
# -----------------------------------

suite "SERVER API [unit]":
  createClient
  
  testAPI "serverInfo":
    let resp = cc.serverInfo()
    check ["couchdb", "version"] in resp

suite "DATABASE API [unit]":
  createClient
  const dbNames = ["sample1", "sample2"]

  testAPI "create DB":
    for db in dbNames:
      cc.createDB(db)

    let dbs = cc.allDBs
    check dbNames.allIt dbs.contains(it)

  testAPI "delete DB":
    for db in dbNames:
      cc.deleteDB(db)
    
    let dbs = cc.allDBs
    check not dbNames.anyIt(dbs.contains(it))

  testAPI "isDBexists":
    check not cc.isDBexists("movies")
    cc.createDB("movies")
    check cc.isDBexists("movies")
    cc.deleteDB("movies")

echo " :::::: not covered APIs :::::: "
echo (incompletelyCoveredProcs().mapIt " - " & it.info.procName).join "\n"
# echo incompletelyCoveredProcs() FIXME