import unittest, httpcore, json, sequtils, strutils, strformat, sets
import coverage
import mycouch/[api, private/exceptions]


func contains(json: JsonNode, keys: openArray[string]): bool =
  for k in keys:
    if k notin json:
      return false
  true

func contains(s, keys: openArray[string]): bool =
  (s.toHashSet.intersection keys.toHashSet).len == keys.len


template testAPI(name, body) {.dirty.}=
  test name:
    try:
      body

    except CouchDBError as e:
      echo fmt"API Error: {e.responseCode}"
      echo "details: ", e.info
      check false

template createClient {.dirty.}=
  var cc = newCouchDBClient()
  discard cc.cookieAuthenticate("admin", "admin")

# -----------------------------------

suite "SERVER API [unit]":
  var cc = newCouchDBClient()
  
  testAPI "cookie auth":
    discard cc.cookieAuthenticate("admin", "admin")
  
  testAPI "delete session":
    cc.deleteCookieSession

    expect CouchDBError:
      cc.createDB "sample1"

  discard cc.cookieAuthenticate("admin", "admin")

  testAPI "get session":
    check "userCtx" in cc.getCurrentSession

  testAPI "is up?":
    check cc.up()

  testAPI "serverInfo":
    let resp = cc.serverInfo()
    check ["couchdb", "version"] in resp

  testAPI "gen uuids":
    let req = cc.uuids(3)
    check req.len == 3

  testAPI "active tasks":
    check cc.activeTasks().kind == JArray

  # nodes ----------------------------
  testAPI "node status":
    check "name" in cc.nodeInfo()

  testAPI "node info":
    check ["all_nodes", "cluster_nodes"] in cc.membership()

suite "DATABASE API [unit]":
  createClient
  const 
    dbNames = ["sample1", "sample2"]
    db1 = dbNames[0]

  testAPI "create DB":
    for db in dbNames:
      cc.createDB(db)

    let dbs = cc.allDBs
    check dbNames.allIt dbs.contains(it)
    check cc.isDBexists(db1)

  testAPI "DBs info":
    let res1 = cc.getDBinfo db1
    check res1["db_name"].str == db1

    let res2 = cc.DBsInfo dbNames
    check (res2.mapIt it["key"].str) == dbNames.toseq

  testAPI "delete DB":
    for db in dbNames:
      cc.deleteDB(db)
    
    let dbs = cc.allDBs

    check not dbNames.anyIt dbs.contains(it)
    check not cc.isDBexists(db1)

suite "DOCUMENT API [unit]":
  createClient
  
  const db = "doc_api_test"
  var docId, docRev: string

  cc.createDB db

  testAPI "create Doc":
    let res = cc.createDoc(db, %*{
      "job-title": "programmer",
      "name": "hamid",
      "age": 21,
    })

    (docId, docRev) = (res["id"].str, res["rev"].str)
    check cc.getDoc(db, docid)["name"].str == "hamid"

  testAPI "edit Doc":
    let res = cc.createOrUpdateDoc(db, docid, docrev, %*{
      "name": "ali"
    })

    docRev = res["rev"].str
    check cc.getDoc(db, docid, docrev)["name"].str == "ali"

  testAPI "delete Doc":
    cc.deleteDoc(db, docid, docrev)

    expect CouchDBError:
      discard cc.getDoc(db, docid)

  # testAPI "copy doc":
  #   let docid = 
  #     cc.createDoc(db, %* {"name": "hamid"})["id"].str

  #   let cpDocid = cc.uuids[0]
  #   let res = cc.copyDoc(db, docid, cpDocid)

  #   check res["id"].str == cpdocid

  var docs: JsonNode

  testAPI "bulk Docs":
    docs = cc.bulkDocs(db, %* [
      {
        "name": "mahdi",
        "age": 21,
      },
      {
        "name": "reza",
        "age": 24
      },
      {
        "name": "ahmed",
        "age": 33,
      }
    ])

    let ids = docs.mapIt %*{"id": it["id"]}
    let res  =cc.bulkGet(db, % ids)["results"]
    let names = res.mapIt it["docs"][0]["ok"]["name"].str

    check ["mahdi" ,"reza", "ahmed"] in names
  

  cc.deleteDB db


when isMainModule:
  let icp = incompletelyCoveredProcs()
  echo "\n :::::: uncovered APIs :::::: " & $icp.len
  echo (icp.mapIt " - " & it.info.procName).join "\n"
  # echo incompletelyCoveredProcs() # FIXME