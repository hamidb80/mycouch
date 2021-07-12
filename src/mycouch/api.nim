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

# initiate -----------------------------------------------

proc newCouchDBClient*(host: string = "http://localhost", port = 5984): CouchDBClient =
  let client = newHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})

  CouchDBClient(hc: client, baseUrl: fmt"{host}:{port}")

# ----------------------------------------------------------------------

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

proc allDBs*(self; descending = false, limit = -1, skip = 0, startkey = newJObject(), endKey = newJObject()): JsonNode {.captureDefaults.}=
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

proc DBsInfo*(self; keys: openArray[string]): JsonNode=
  ## https://docs.couchdb.org/en/latest/api/server/common.html#dbs-info
  
  let req = self.hc.post(fmt"{self.baseUrl}/_dbs_info", $ %*{"keys": keys})

  doAssert req.code == Http200 # or bad request 400
  return req.body.parseJson

# TODO (cluster setup) https://docs.couchdb.org/en/latest/api/server/common.html#cluster-setup

type FeedVariants = enum
  FVNormal = "normal"
  FVLongPoll = "longpoll"
  FVContinuous = "continuous"
  FVEventSource = "eventsource"
proc DBupdates*(self; feed: string, timeout= 60, heartbeat= 60000, since=""): JsonNode=
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

proc membership*(self): JsonNode=
  ## https://docs.couchdb.org/en/latest/api/server/common.html#membership
  let req = self.hc.get(fmt"{self.baseUrl}/_membership")

  doAssert req.code == Http200
  return req.body.parseJson

proc replicate*(self; 
  source, target: string,
  cancel, continuous, create_target = false, 
  create_target_params: JsonNode= newJObject(),
  doc_ids = newseq[string](),
  filter: string = "",
  source_proxy, target_proxy: string= ""
): JsonNode {.captureDefaults.}=
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

# TODO: add doc uri in doc of every api
proc login*(self; name, pass: string) =
  let resp = self.hc.post(fmt"{self.baseUrl}/_session", $ %*{
    "name": name, "password": pass
  })
  assert resp.code == Http200
  assert resp.headers.table.hasKey "set-cookie"

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

proc createDoc*(self; dbName: string; doc: JsonNode): JsonNode =
  let resp = self.hc.post(fmt"{self.baseUrl}/{dbName}/", $doc)

  assert resp.code == Http201
  resp.body.parseJson

proc updateDoc*(self; dbName: string; doc: JsonNode): JsonNode =
  assert (doc.hasKey "_id") and (doc.hasKey "_rev"), "doc must have '_id' & '_rev'"

  let resp = self.hc.put(fmt"{self.baseUrl}/{dbName}/", $doc)
  assert resp.code == Http200

  resp.body.parseJson

proc deleteDoc*(self; dbName: string; id, rev: string): JsonNode =
  let resp = self.hc.delete(fmt"{self.baseUrl}/{dbName}/{id}?rev={rev}")

  assert resp.code == Http200

  resp.body.parseJson

proc bulkInsert*(self; dbName: string; docs: openArray[JsonNode]): JsonNode =
  let resp = self.hc.post(fmt"{self.baseUrl}/{dbName}/", $docs)

  assert resp.code == Http201

  resp.body.parseJson

proc bulkUpdate*(self; dbName: string; docs: openArray[JsonNode]): JsonNode =
  # assert (doc.hasKey "_id") and (doc.hasKey "_rev"), "doc must have '_id' & '_rev'"

  let resp = self.hc.put(fmt"{self.baseUrl}/{dbName}/", $docs)
  assert resp.code == Http200

  resp.body.parseJson
