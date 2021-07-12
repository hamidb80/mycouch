import
  httpclient, uri,
  json, tables, strformat, strutils
import ./private/utils

type
  CouchDBClient* = object
    hc*: HttpClient
    baseUrl*: string

using
  self: CouchDBClient

# INITIATE -----------------------------------------------

proc newCouchDBClient*(host: string = "http://localhost", port = 5984): CouchDBClient =
  let client = newHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})

  CouchDBClient(hc: client, baseUrl: fmt"{host}:{port}")

# SERVER API ----------------------------------------------------------------------

proc serverInfo*(self): JsonNode =
  ## https://docs.couchdb.org/en/stable/api/server/common.html#api-server-root
  let req = self.hc.get(fmt"{self.baseUrl}/")

  doAssert req.code == Http200
  return req.body.parseJson

proc activeTasks*(self): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#active-tasks
  let req = self.hc.get(fmt"{self.baseUrl}/_active_tasks/")

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

proc allDBs*(self; descending = false, limit, skip = 0, startkey, endKey = newJObject()): JsonNode {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#all-dbs

  var queryParams = @[
    ("descending", $descending),
    ("skip", $skip),
  ]
  queryParams.addIfIsNotDefault([
    limit,
    startKey,
    endKey,
  ], allDBsDefaults)

  let req = self.hc.get(fmt"{self.baseUrl}/_all_dbs/?" & encodeQuery(queryParams))

  doAssert req.code == Http200
  return req.body.parseJson

proc DBsInfo*(self; keys: openArray[string]): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#dbs-info

  let req = self.hc.post(fmt"{self.baseUrl}/_dbs_info", $ %*{"keys": keys})

  doAssert req.code == Http200 # or bad request 400
  return req.body.parseJson

# TODO (cluster setup) https://docs.couchdb.org/en/latest/api/server/common.html#cluster-setup

type FeedVariants* = enum
  FVNormal = "normal"
  FVLongPoll = "longpoll"
  FVContinuous = "continuous"
  FVEventSource = "eventsource"
proc DBupdates*(self; feed: string, timeout = 60, heartbeat = 60000, since = ""): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#db-updates
  let queryParams = @[
    ("feed", feed),
    ("since", since),
    ("timeout", $timeout),
    ("heartbeat", $heartbeat),
  ]
  let req = self.hc.get(fmt"{self.baseUrl}/_db_updates/?" & encodeQuery(queryParams))

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

proc membership*(self): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#membership
  let req = self.hc.get(fmt"{self.baseUrl}/_membership")

  doAssert req.code == Http200
  return req.body.parseJson

proc replicate*(self;
  source, target: string,
  cancel, continuous, create_target = false,
  create_target_params: JsonNode = newJObject(),
  doc_ids = newseq[string](),
  filter: string = "",
  source_proxy, target_proxy: string = ""
): JsonNode {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#replicate

  var body = %* {
    "source": source,
    "target": target,
  }
  body.addIfIsNotDefault([
    cancel,
    continuous,
    create_target,
    doc_ids,
    filter,
    source_proxy, target_proxy,
  ], replicateDefaults)
  let req = self.hc.post(fmt"{self.baseUrl}/_replicate", $body)

  doAssert req.code in {Http200, Http202}
  return req.body.parseJson

proc schedulerJobs*(self; limit, skip = 0): JsonNode {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#scheduler-jobs

  var queryParams = newseq[DoubleStrTuple]()
  queryParams.addIfIsNotDefault([
    limit,
    skip
  ], schedulerJobsDefaults)

  let req = self.hc.get(fmt"{self.baseUrl}/_all_dbs/?" & encodeQuery(queryParams))

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

proc schedulerDocs*(self; replicatorDB, doc_id = "", limit, skip = 0, ): JsonNode {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#scheduler-docs
  ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_scheduler-docs-replicator_db
  let url =
    fmt"{self.baseUrl}/_scheduler/docs" &
    (
      if replicatorDB != "": fmt"/{replicatorDB}"
      else:
        var queryParams = newseq[DoubleStrTuple]()
        queryParams.addIfIsNotDefault([limit, skip], schedulerJobsDefaults)
        "?" & encodeQuery(queryParams)
    )

  let req = self.hc.get(url)

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

proc schedulerDoc*(self; replicatorDB, doc_id: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_scheduler-docs-replicator_db-docid
  let req = self.hc.get(fmt"{self.baseUrl}/_scheduler/docs/{replicatorDB}/{doc_id}")

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

proc nodeInfo*(self; nodeName: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
  let req = self.hc.get(fmt"{self.baseUrl}/_node/{nodeName}")

  doAssert req.code == Http200
  return req.body.parseJson

proc nodeStats*(self; nodeName: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
  let req = self.hc.get(fmt"{self.baseUrl}/_node/{nodeName}/_stats")

  doAssert req.code == Http200
  return req.body.parseJson

proc nodeSystem*(self; nodeName: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
  let req = self.hc.get(fmt"{self.baseUrl}/_node/{nodeName}/_system")

  doAssert req.code == Http200
  return req.body.parseJson

proc nodeRestart*(self; nodeName: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name-restart
  let req = self.hc.post(fmt"{self.baseUrl}/_node/{nodeName}/_restart")

  doAssert req.code == Http200
  return req.body.parseJson

## maybeTODO: https://docs.couchdb.org/en/latest/api/server/common.html#search-analyze

proc up*(self; nodeName: string): bool =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#up
  self.hc.get(fmt"{self.baseUrl}/_up").code == Http200 # or 404

proc uuids*(self; count = 1): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#uuids
  let req = self.hc.get(fmt"{self.baseUrl}/_uuids?count={count}")

  doAssert req.code == Http200 # or 400
  return req.body.parseJson

proc reshard*(self): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#reshard
  let req = self.hc.get(fmt"{self.baseUrl}/_reshard")

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

proc reshardState*(self): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-state
  let req = self.hc.get(fmt"{self.baseUrl}/_reshard/state")

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

type ReshardStates* = enum
  stopped = "stopped"
  running = "running"
proc changeReshardState*(self; state: string, state_reason = "") {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#put--_reshard-state

  var body = %* {"state": state}
  body.addIfIsNotDefault([state_reason], changeReshardStateDefaults)

  let req = self.hc.put(fmt"{self.baseUrl}/_reshard/state", $ body)
  doAssert req.code == Http200 # 400 or 401

proc reshardJobs*(self; jobId = ""): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs
  ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs-jobid
  let req = self.hc.get(fmt"{self.baseUrl}/_reshard/jobs/" & jobId)

  doAssert req.code == Http200 # or 401
  return req.body.parseJson

proc createReshadJob*(self; `type`, db: string, node, `range`, shard, error = "") {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#post--_reshard-jobs
  var body = %* {
    "type": `type`,
    "db": db,
  }
  body.addIfIsNotDefault([
    node, `range`, shard, error
  ], createReshadJobDefaults)

  let req = self.hc.post(fmt"{self.baseUrl}/_reshard/jobs", $ body)
  doAssert req.code == Http200 # or bad request 400

proc deleteReshadJob*(self; jobId: string) =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#delete--_reshard-jobs-jobid
  let req = self.hc.post(fmt"{self.baseUrl}/_reshard/jobs/{jobid}")
  doAssert req.code == Http200 # or bad request 400

proc reshadJobState*(self; jobId: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs-jobid-state
  let req = self.hc.get(fmt"{self.baseUrl}/_reshard/jobs/{jobId}/state")
  doAssert req.code == Http200 # or 401, 404

  req.body.parseJson

proc changeReshardJobState*(self; jobId, state: string, state_reason = "") {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/server/common.html#put--_reshard-state

  var body = %* {"state": state}
  body.addIfIsNotDefault([state_reason], changeReshardStateDefaults)

  let req = self.hc.put(fmt"{self.baseUrl}/_reshard/jobs/{jobId}/state", $ body)
  doAssert req.code == Http200 # 400 or 401

# DATEBASE API ------------------------------------------------------------

proc isDBexists*(self; dbname: string): bool =
  ## https://docs.couchdb.org/en/latest/api/database/common.html#head--db
  let req = self.hc.head(fmt"{self.baseUrl}/{dbname}")
  req.code == Http200

proc getDBinfo*(self; dbname: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/database/common.html#get--db
  let req = self.hc.get(fmt"{self.baseUrl}/{dbname}")

  doAssert req.code == Http200
  req.body.parseJson

proc createDB*(self;dbname:string, q, n = -1, partioned= false): JsonNode {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/database/common.html#put--db
  var body = %* {}
  body.addIfIsNotDefault([q,n, partioned], createDBDefaults)

  let req = self.hc.put(fmt"{self.baseUrl}/{dbname}")

  doAssert req.code in {Http201, Http202}
  req.body.parseJson

proc deleteDB*(self;dbname:string)=
  ## https://docs.couchdb.org/en/latest/api/database/common.html#delete--db
  let req = self.hc.delete(fmt"{self.baseUrl}/{dbname}")

  doAssert req.code in {Http200, Http202}

proc createDoc*(self; dbName: string; doc: JsonNode, batch=""): JsonNode {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/database/common.html#post--db
  var queryParams: seq[DoubleStrTuple]
  queryParams.addIfIsNotDefault([batch], createDocDefaults)
  let req = self.hc.post(fmt"{self.baseUrl}/{dbName}/?" & encodeQuery(queryParams), $doc)

  doAssert req.code in {Http201, Http202}
  req.body.parseJson

proc allDocs*(self; dbName: string): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-all-docs
  let req = self.hc.get(fmt"{self.baseUrl}/{dbName}/_all_docs/")

  doAssert req.code == Http200
  req.body.parseJson

proc allDocsKeys*(self; dbName: string, keys: seq[string]): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#post--db-_all_docs
  let req = self.hc.post(fmt"{self.baseUrl}/{dbName}/_all_docs/", $ %*{"keys": keys})

  doAssert req.code == Http200
  req.body.parseJson

proc designDocs*(self; dbName: string, 
  conflicts, descending= false,
  startkey, endkey ="",
  startkey_docid, endkey_docid = "",
  include_docs= false,
  inclusive_end= true,
  key = "",
  keys = newseq[string](),
  limit, skip= 0,
  update_seq= false,
): JsonNode {.captureDefaults.}=
  var queryParams: seq[DoubleStrTuple]
  queryParams.addIfIsNotDefault([
    conflicts, descending,
    startkey, endkey,
    startkey_docid, endkey_docid,
    include_docs,
    inclusive_end,
    key,
    limit, skip,
    update_seq,
  ], designDocsDefaults)
  ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-design-docs
  
  let 
    url = fmt"{self.baseUrl}/{dbName}/_design_docs/?" & encodeQuery(queryParams)
    req = 
      if keys == designDocsDefaults.keys:
        self.hc.get(url)
      else:
        self.hc.post(url, $ %*{"keys": keys})

  doAssert req.code == Http200
  req.body.parseJson

proc allDocsQueries*(self; dbName: string, queries: JsonNode): JsonNode =
  ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#post--db-_all_docs-queries
  let req = self.hc.post(fmt"{self.baseUrl}/{dbName}/_all_docs/queries", $queries)

  doAssert req.code == Http200
  req.body.parseJson

proc bulkGet*(self; dbName: string, docs: JsonNode, revs=false): JsonNode {.captureDefaults.} =
  ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-bulk-get
  var queryParams: seq[DoubleStrTuple]
  queryParams.addIfIsNotDefault([revs], bulkGetDefaults)
  let req = self.hc.post(fmt"{self.baseUrl}/{dbName}/_bulk_get?" & encodeQuery(queryParams), $docs)

  doAssert req.code == Http200
  req.body.parseJson

# DOCUMENTs API ------------------------------------------------------------

# DESIGN DOCUMENTs API ------------------------------------------------------------

# PARTIONED DATABASEs API ------------------------------------------------------------

# LOCAL DOCUMENTs API ------------------------------------------------------------

# -------------------------------------------------------------------------
# TODO: add doc uri in doc of every api
proc login*(self; name, pass: string) =
  let resp = self.hc.post(fmt"{self.baseUrl}/_session", $ %*{
    "name": name, "password": pass
  })
  doAssert resp.code == Http200
  doAssert resp.headers.table.hasKey "set-cookie"

  #  if stores like this: @["AuthSession=<CODE>; Version=N; Expires=<WEEK_DAY>, <DATE> GMT; Max-Age=600; Path=/; HttpOnly"]
  self.hc.headers.table["Cookie"] = resp.headers.table["set-cookie"]

proc find*(self; dbName: string; mangoQuery: JsonNode): JsonNode =
  self.hc.post(fmt"{self.baseUrl}/{dbName}/_find", $mangoQuery)
  .body.parseJson["docs"]

proc getDoc*(self; dbName: string; id: string, rev = "", include_docs: bool = false): JsonNode =
  self.hc.get(fmt"{self.baseUrl}/{dbName}/{id}" & (
    if rev == "": ""
    else: fmt"?rev={rev}"
  ))
  .body.parseJson

proc updateDoc*(self; dbName: string; doc: JsonNode): JsonNode =
  doAssert (doc.hasKey "_id") and (doc.hasKey "_rev"), "doc must have '_id' & '_rev'"

  let resp = self.hc.put(fmt"{self.baseUrl}/{dbName}/", $doc)
  doAssert resp.code == Http200

  resp.body.parseJson

proc deleteDoc*(self; dbName: string; id, rev: string): JsonNode =
  let resp = self.hc.delete(fmt"{self.baseUrl}/{dbName}/{id}?rev={rev}")

  doAssert resp.code == Http200

  resp.body.parseJson

proc bulkInsert*(self; dbName: string; docs: openArray[JsonNode]): JsonNode =
  let resp = self.hc.post(fmt"{self.baseUrl}/{dbName}/", $docs)

  doAssert resp.code == Http201

  resp.body.parseJson

proc bulkUpdate*(self; dbName: string; docs: openArray[JsonNode]): JsonNode =
  # doAssert (doc.hasKey "_id") and (doc.hasKey "_rev"), "doc must have '_id' & '_rev'"

  let resp = self.hc.put(fmt"{self.baseUrl}/{dbName}/", $docs)
  doAssert resp.code == Http200

  resp.body.parseJson
