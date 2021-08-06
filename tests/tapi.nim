import
  unittest, asyncdispatch, httpcore, json, sequtils, strutils, strformat,
  threadpool, sets, os, mimetypes
import coverage
import mycouch/[api, queryGen]

let
  uname = getEnv "COUCHDB_ADMIN_NAME"
  upass = getEnv "COUCHDB_ADMIN_PASS"

if uname.len * upass.len == 0:
  quit("'COUCHDB_ADMIN_NAME' & 'COUCHDB_ADMIN_PASS' must be set")

# -----------------------------------------

func contains(json: JsonNode, keys: openArray[string]): bool =
  for k in keys:
    if k notin json:
      return false
  true

func contains(s, keys: openArray[string]): bool =
  (s.toHashSet.intersection keys.toHashSet).len == keys.len

template testAPI(name, body) {.dirty.} =
  test name:
    try:
      body
    except CouchDBError as e:
      echo fmt"API Error: {e.responseCode}"
      echo "details: ", e.info
      check false

template createClient(cc): untyped =
  var cc = newCouchDBClient()
  discard cc.cookieAuth(uname, upass)

# -----------------------------------------

suite "SERVER API [unit]":
  var cc = newCouchDBClient()

  testAPI "cookie auth":
    discard cc.cookieAuth(uname, upass)

  testAPI "delete session":
    cc.removeAuth

    expect CouchDBError:
      cc.createDB "dbname"

  discard cc.cookieAuth(uname, upass)

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

  testAPI "reshard states":
    check "total" in cc.getReshards
    check "state" in cc.reshardState
    cc.changeReshardState RSrunning

  var mainNode: string
  testAPI "membership":
    let req = cc.membership()
    check ["all_nodes", "cluster_nodes"] in req

    mainnode = req["all_nodes"][0].str

  # nodes ----------------------------

  testAPI "node status":
    check "name" in cc.nodeInfo()

  testAPI "node stats":
    discard cc.nodeStats()

  testAPI "node system":
    check "uptime" in cc.nodeSystem()

  testAPI "node config":
    let req = cc.getNodeConfig mainNode
    check "log" in req

  testAPI "get node section config":
    let req = cc.getNodeSectionConfig(mainnode, "log")
    check "level" in req

  var lastValue: string
  testAPI "get node section config key":
    let req = cc.getNodeSectionKeyConfig(mainnode, "log", "level")
    check req.str in ["debug", "info", "notice", "warning", "warn", "error",
        "err", "critical", "crit", "alert", "emergency", "emerg", "none"]

    lastValue = req.str

  testAPI "delete node section config key":
    let req = cc.deleteNodeSectionKeyConfig(mainnode, "log", "level")
    check req.str == lastValue

  testAPI "update node section config key":
    discard cc.updateNodeSectionKeyConfig(mainnode, "log", "level", %lastValue)

  testAPI "reload config":
    cc.reloadConfigs(mainNode)

suite "DATABASE API":
  createClient cc
  const
    dbNames = ["sample1", "sample2"]
    db1 = dbNames[0]
    pdb = "pdb" # partitioned db

  createClient nc
  let dbChangeFeed = spawn nc.DBupdates(FVLongPoll, timeout = 5)

  testAPI "create DB":
    for db in dbNames:
      cc.createDB(db)

    let dbs = cc.allDBs
    check dbNames.allIt dbs.contains(it)
    check cc.isDBexists(db1)

  testAPI "db change feed":
    ## The existence of the "_global_changes" database is required to use this endpoint
    let res = ^dbChangeFeed
    check res["results"].allIt it["db_name"].str in dbnames

  testAPI "DBs info":
    let res1 = cc.getDBinfo db1
    check res1["db_name"].str == db1

    let res2 = cc.DBsInfo dbNames
    check (res2.mapIt it["key"].str) == dbNames.toseq

    check "shards" in cc.getshards db1

  testAPI "security":
    let sec = cc.getSecurity db1
    check ["admins", "members"] in sec

    cc.setSecurity(db1, sec["admins"], sec["members"])

  testAPI "revision limit":
    let lm = cc.getRevsLimit db1
    cc.setRevsLimit db1, lm

  testAPI "compact DB":
    cc.compact(db1)

  testAPI "local docs":
    discard cc.getLocalDocs(db1)

  testAPI "replicate": # replication creates a scheduler job
    discard cc.replicate(
      dbnames[0],
      dbnames[1],
      continuous = true
    )

  sleep 1000 # wait for databse to perform replication

  var
    scheduler_doc1Id: string
    repicatorDB: string
  testAPI "scheduler jobs":
    let res = cc.schedulerJobs
    check "jobs" in res

    scheduler_doc1Id = res["jobs"][0]["doc_id"].str
    repicatorDB = res["jobs"][0]["database"].str

  testAPI "scheduler docs":
    check "docs" in cc.schedulerDocs()

  testAPI "scheduler doc":
    check "info" in cc.getSchedulerDoc(repicatorDB, scheduler_doc1Id)

  testAPI "sync shards":
    cc.syncShards(db1)

  testAPI "create reshard job":
    let req = cc.createReshardJob db1
    check req.allIt it["ok"].getBool

  var reshardJobIds: seq[string]
  testAPI "get reshard jobs":
    let res = cc.reshardJobs
    check "jobs" in res
    reshardJobids = (res["jobs"].mapIt it["id"].str)[^2..^1] # the 2 last jobs [added jobs]

    check "state" in cc.getReshardJobState reshardJobids[0]

  testAPI "change reshard job state":
    cc.changeReshardJobState reshardJobids[0], "stopped"

  testAPI "reshard delete job":
    for jid in reshardJobids:
      cc.deleteReshadJob jid

  testAPI "delete DB":
    for db in dbNames:
      cc.deleteDB(db)

    let dbs = cc.allDBs

    check not dbNames.anyIt dbs.contains(it)
    check not cc.isDBexists(db1)

  testAPI "partitioned db":
    cc.createDB(pdb, partitioned = true)
    discard cc.getPartitionInfo(pdb, "somepartition")
    cc.deleteDB pdb

  # testAPI "DB updates":
    # let updates = spawn cc.changes(db1, FVLongPoll)

suite "DOCUMENT API":
  createClient cc
  const db = "doc_api_test"
  cc.createDB db

  var docId, docRev: string
  testAPI "create Doc":
    let res = cc.createDoc(db, %*{
      "job-title": "programmer",
      "name": "hamid",
      "age": 21,
    })

    (docId, docRev) = (res["id"].str, res["rev"].str)
    check cc.getDoc(db, docid)["name"].str == "hamid"
    discard cc.getDoc(db, docid, headonly = true)

  testAPI "edit Doc":
    let res = cc.createOrUpdateDoc(db, docid, docrev, %*{
      "name": "ali"
    })

    docRev = res["rev"].str
    check cc.getDoc(db, docid, docrev)["name"].str == "ali"

  testAPI "shards doc":
    check "range" in cc.shardsDoc(db, docid)

  var m = newMimetypes()
  const
    attname = "file1"
    filePath = "./tests/assets/file.txt"
  testAPI "upload Doc attatchment":
    let req = cc.uploadDocAtt(db, docid, attname,
      m.getMimeType("txt"),
      readfile(filePath),
      rev = docrev)

    docrev = req["rev"].str

  testAPI "get Doc attatchment":
    let req = cc.getDocAtt(db, docid, attname)
    check req.content == readFile(filePath)

  testAPI "delete Doc attatchment":
    let req = cc.deleteDocAtt(db, docid, attname, docrev)
    docrev = req["rev"].str

  testAPI "delete Doc":
    cc.deleteDoc(db, docid, docrev)

    expect CouchDBError:
      discard cc.getDoc(db, docid)

  #[
  testAPI "copy doc":
    let docid = 
      cc.createDoc(db, %* {"name": "hamid"})["id"].str
    let cpDocid = cc.uuids[0]
    let res = cc.copyDoc(db, docid, cpDocid)
    check res["id"].str == cpdocid
  ]#

  var docs: JsonNode
  testAPI "bulk Docs":
    docs = cc.bulkDocs(db, %* [
      {
        "name": "mahdi",
        "age": 21,
      },
      {
        "name": "reza",
        "age": 17
      },
      {
        "name": "ahmed",
        "age": 33,
      }
    ])

    let ids = docs.mapIt %*{"id": it["id"]}
    let res = cc.bulkGet(db, % ids)["results"]
    let names = res.mapIt it["docs"][0]["ok"]["name"].str

    check ["mahdi", "reza", "ahmed"] in names

  testAPI "all docs":
    template checkNames(allDocs) =
      let names = allDocs.filterIt(it["doc"].hasKey "name").mapIt(it["doc"]["name"].str)
      check ["mahdi", "reza", "ahmed"] in names

    let res = cc.allDocs(db, viewQuery(
      include_docs = true
    ))
    checkNames res["rows"]

    # -----------------------------------------

    let req = cc.allDocs(db, %*{"queries": [
      {"include_docs": true}
    ]})
    checkNames req["results"][0]["rows"]

  testAPI "missing revs":
    discard cc.missingRevs(db, %* {
      docs[0]["id"].str: [docs[0]["rev"].str]
    })

  testAPI "revs diff":
    discard cc.revsDiff(db, %* {
      docs[0]["id"].str: [docs[0]["rev"].str]
    })

  const indexName = "by_age"
  var indexDdoc: string
  testAPI "create index":
    let res = cc.createIndex(db, %* {
      "fields": ["age"]
    }, name = indexname)

    indexDdoc = res["id"].str
    discard cc.getDoc(db, res["id"].str)

  testAPI "get index list":
    let res = cc.getindexes(db)

    check ["_all_docs", indexname] in res["indexes"].mapIt it["name"].str

  testAPI "get design docs":
    check "rows" in cc.designDocs(db)
    check "_id" in cc.getDesignDoc(db, indexddoc["_design/".len..^1])
    discard cc.getDesignDoc(db, indexddoc["_design/".len..^1], headonly = true)
    check "view_index" in cc.getDesignDocInfo(db, indexddoc["_design/".len..^1])

  testAPI "compact design docs":
    cc.compactDesignDoc db, indexDdoc["_design/".len..^1]

  testAPI "view clean up":
    cc.viewCleanup db

  testAPI "find":
    let res = cc.find(db, mango(
      PS(@age > 19),
      fields = @["name", "age"],
      use_index = indexname
    ))

    check:
      res["docs"].len > 0
      res["docs"].allIt it["age"].getInt > 19

    # --------------------------------

    let req = cc.find(db, mango(
      PS(@age > 19),
      fields = @["name", "age"],
      use_indexes = @["name", "age"],
    ))

    check:
      req["docs"].len > 0
      req["docs"].allIt it["age"].getInt > 19

  testAPI "explain":
    let res = cc.find(db, mango(PS(nil)), explain = true)

    check "index" in res

  testAPI "delete index":
    cc.deleteIndex(db, indexDdoc, indexname)

  testAPI "purge":
    let req = cc.purge(db, %* {
      docs[0]["id"].str: [docs[0]["rev"].str]
    })

    check req["purged"][docs[0]["id"].str].len == 1

  testAPI "purged info limit":
    let n = cc.getPurgedInfosLimit(db)
    cc.setPurgedInfosLimit db, n

  const
    viewname = "group-by-first-letter"
    ddoc = "my-view"
  var ddocRev: string
  testAPI "create design doc":
    let req = cc.createOrUpdateDesignDoc(db, ddoc, views = %*{
      viewname: {
        "map": """
          function (doc) {  
            if (doc.name)
              emit(doc.name[0], null);
          }
        """,

        "reduce": $PRFcount
      }
    })

    ddocRev = req["rev"].str

    let res = cc.getDesignDoc(db, ddoc)
    check viewname in res["views"]

  testAPI "get view":
    # TODO check that later ...
    let req = cc.getView(db, ddoc, viewname, viewQuery(reduce = false))
    echo req.pretty

    let res = cc.getView(db, ddoc, viewname, viewQuery())
    echo res.pretty

  testAPI "update design doc":
    let req = cc.createOrUpdateDesignDoc(db, ddoc, ddocrev, views = %*{
      viewname: {
        "map": """
          function (doc) {}
        """
      }
    })

    ddocRev = req["rev"].str

  testAPI "run update func":
    discard cc.createOrUpdateDesignDoc(db, "d2", updates = %*{
      "my-update-func": """
        function(doc, req){
          doc.number += 1
          return [doc, "get it"]
        }
      """
    })

    discard cc.createDoc(db, %* {"_id": "test-doc", "number": 1})
    let resp = cc.execUpdateFunc(db, "d2", "my-update-func", %*{}, "test-doc")

    check resp.body == "get it"

    let req = cc.getDoc(db, "test-doc")
    check req["number"].getInt == 2

  testAPI "delete design doc":
    cc.deleteDesignDoc(db, ddoc, ddocrev)

  # TODO add test for ddoc att

  testAPI "changes":
    createClient nc

    proc fake: JsonNode =
      {.cast(gcsafe).}:
        nc.changes(db, FVLongPoll, timeout = 5, include_docs = true)

    let t = spawn fake()
    let newDocId = cc.createDoc(db, %* {"name": "ali"})["id"]

    echo (^t)["results"][0]["id"] == newDocId

  cc.deleteDB db

suite "async":
  let acc = newAsyncCouchDBClient()

  test "up":
    check (waitFor acc.up()) == true

test "restart":
  createClient cc
  cc.nodeRestart


when isMainModule:
  let icp = incompletelyCoveredProcs()
  echo "\n :::::: uncovered APIs :::::: " & $icp.len
  echo (icp.mapIt " - " & it.info.procName).join "\n"
  # echo incompletelyCoveredProcs() # FIXME improve coverage api
