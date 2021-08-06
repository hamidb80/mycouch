import
  httpclient, httpcore, asyncdispatch, uri,
  json, tables, strformat, strutils, sequtils
import coverage
import ./private/utils

type
  BaseCouchDBClient = object of RootObj
    baseUrl*: string

  AsyncCouchDBClient* = object of BaseCouchDBClient
    hc*: AsyncHttpClient

  CouchDBClient* = object of BaseCouchDBClient
    hc*: HttpClient
  
  CC = CouchDBClient
  AsyncCC = AsyncCouchDBClient

  Attachment* = object
    etag*: string
    contentEncoding*: string
    content*: string

  FeedVariants* = enum
    FVNormal = "normal"
    FVLongPoll = "longpoll"
    FVContinuous = "continuous"
    FVEventSource = "eventsource"

  BatchVariants* = enum
    BVNon = ""
    BVOk = "ok"

  UpdateVariants* = enum
    UVTrue = "true"
    UVFalse = "false"
    UVLazy = "lazy"

  StyleVariants* = enum
    SVMainOnly = "main_only"
    SVAllDocs = "all_docs"

  ReshardStates* = enum
    RSstopped = "stopped"
    RSrunning = "running"

  PredefindReduceFunc* = enum
    PRFsum = "_sum"
    PRFcount = "_count"
    PRFstats = "_stats"
    PRFapprox_count_distinct = "_approx_count_distinct"


using
  CC: CouchDBClient
  ACC: AsyncCouchDBClient 
  self: CouchDBClient
  db: string
  docid: string
  ddoc: string
  attname: string
  view: string
  node: string
  section: string
  partition: string

# CLIENT OBJECT -----------------------------------------------

proc newCouchDBClient*(host: string = "http://localhost", port = 5984): CouchDBClient =
  ## creates new couchdb client - it is used for APIs
  var client = newHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})
  CouchDBClient(hc: client, baseUrl: fmt"{host}:{port}")

proc newAsyncCouchDBClient*(host: string = "http://localhost", port = 5984): AsyncCouchDBClient =
  ## creates new couchdb client - it is used for APIs
  var client = newAsyncHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})
  AsyncCouchDBClient(hc: client, baseUrl: fmt"{host}:{port}")


proc changeHeaders(
  lastHeaders: HttpHeaders,
  changedData: openArray[tuple[k: string, v: string]]
): HttpHeaders =
  result.deepcopy lastHeaders

  for (key, val) in changedData:
    result.add key, val

type 
  CouchDBError* = object of Defect
    responseCode*: HttpCode
    info*: JsonNode

func newCouchDBError*(respCode: HttpCode, info: JsonNode): ref CouchDBError=
  result = newException(CouchDBError, "")
  result.responseCode = respCode
  result.info = info

template castError(res: Response) =
  if not res.code.is2xx:
    raise newCouchDBError(res.code, res.body.parseJson)

template castError(res: AsyncResponse) =
  if not res.code.is2xx:
    raise newCouchDBError(res.code, (await res.body).parseJson)


# SERVER API ----------------------------------------------------------------------

addTestCov:
  proc serverInfo*(self: CC | AsyncCC): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#api-server-root
    let req = await self.hc.get(fmt"{self.baseUrl}/")

    castError req
    return (await req.body).parseJson

  proc activeTasks*(self: CC | AsyncCC): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#active-tasks
    let req = await self.hc.get(fmt"{self.baseUrl}/_active_tasks/")

    castError req
    return (await req.body).parseJson

  proc allDBs*(self: CC | AsyncCC,
    descending = false,
    limit,
    skip = 0,
    startkey,
    endKey = newJObject()
  ): Future[seq[string]] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#all-dbs

    var queryParams = @[
      ("descending", $descending),
      ("skip", $skip),
    ].createNadd([
      limit,
      startKey,
      endKey,
    ], defaults)

    let req = await self.hc.get(fmt"{self.baseUrl}/_all_dbs/?" & encodeQuery(queryParams))

    castError req
    return (await req.body).parseJson.mapIt it.str

  proc DBsInfo*(self: CC | AsyncCC; keys: openArray[string]): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#dbs-info
    let req = await self.hc.post(fmt"{self.baseUrl}/_dbs_info", $ %*{"keys": keys})

    castError req
    return (await req.body).parseJson

  # ## TODO https://docs.couchdb.org/en/latest/api/server/common.html#get--_cluster_setup
  # ## https://docs.couchdb.org/en/latest/api/server/common.html#post--_cluster_setup

  proc DBupdates*(self: CC | AsyncCC; feed: FeedVariants, 
    timeout = 60, 
    heartbeat = 60000, 
    since = "now"
  ): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#db-updates
    let req = await self.hc.get(fmt"{self.baseUrl}/_db_updates/?" & encodeQuery([
      ("feed", $feed),
      ("since", $since),
      ("timeout", $timeout),
      ("heartbeat", $heartbeat)
    ]))

    castError req
    return (await req.body).parseJson

  proc membership*(self: CC or AsyncCC): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#membership
    let req = await self.hc.get(fmt"{self.baseUrl}/_membership")

    castError req
    return (await req.body).parseJson

  proc replicate*(self: CC or AsyncCC; source, target: string,
    cancel,
    continuous,
    create_target = false,
    create_target_params: JsonNode = newJObject(),
    doc_ids = newseq[string](),
    filter: string = "",
    source_proxy,
    target_proxy: string = ""
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#replicate

    let req = await self.hc.post(fmt"{self.baseUrl}/_replicate", $ createNadd( %* {
      "source": source,
      "target": target,
    }, [
      cancel,
      continuous,
      create_target,
      doc_ids,
      filter,
      source_proxy, target_proxy,
    ], defaults))

    castError req
    return (await req.body).parseJson

  proc schedulerJobs*(self: CC or AsyncCC; limit, skip = 0): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#scheduler-jobs

    let queryParams = newseq[DoubleStrTuple]().createNadd([
      limit,
      skip
    ], defaults)

    let req = await self.hc.get(fmt"{self.baseUrl}/_scheduler/jobs?" & encodeQuery(queryParams))

    castError req
    return (await req.body).parseJson

  proc schedulerDocs*(self: CC or AsyncCC; replicatorDB, doc_id = "", limit, skip = 0, ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#scheduler-docs
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_scheduler-docs-replicator_db
    
    let req = await self.hc.get(
      fmt"{self.baseUrl}/_scheduler/docs" & (
        if replicatorDB != "": fmt"/{replicatorDB}"
        else:
          var queryParams = newseq[DoubleStrTuple]().createNadd([limit, skip], defaults)
          "?" & encodeQuery(queryParams)
    ))

    castError req
    return (await req.body).parseJson

  proc getSchedulerDoc*(self: CC or AsyncCC;replicatorDB, docid: string, ): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_scheduler-docs-replicator_db-docid
    let req = await self.hc.get(fmt"{self.baseUrl}/_scheduler/docs/{replicatorDB}/{docid}")

    castError req
    return (await req.body).parseJson

  proc nodeInfo*(self: CC or AsyncCC; node = "_local"): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
    let req = await self.hc.get(fmt"{self.baseUrl}/_node/{node}")

    castError req
    return (await req.body).parseJson

  proc nodeStats*(self: CC or AsyncCC; node = "_local"): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
    let req = await self.hc.get(fmt"{self.baseUrl}/_node/{node}/_stats")

    castError req
    return (await req.body).parseJson

  proc nodeSystem*(self: CC or AsyncCC; node = "_local"): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_node-node-name-_system
    let req = await self.hc.get(fmt"{self.baseUrl}/_node/{node}/_system")

    castError req
    return (await req.body).parseJson

  proc nodeRestart*(self: CC or AsyncCC; node = "_local") {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name-restart
    let req = await self.hc.post(fmt"{self.baseUrl}/_node/{node}/_restart")

    castError req

  proc searchAnalyze*(self: CC or AsyncCC; analyzer, text: string): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#search-analyze
    let req = await self.hc.post(fmt"{self.baseUrl}/_search_analyze", $ %*{
      "analyzer": analyzer, "text": text
    })

    castError req
    return (await req.body).parseJson

  proc up*(self: CC or AsyncCC): Future[bool] {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#up
    return (await self.hc.get(fmt"{self.baseUrl}/_up")).code == Http200 # or 404

  proc uuids*(self: CC or AsyncCC; count = 1): Future[seq[string]] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#uuids
    let req = await self.hc.get(fmt"{self.baseUrl}/_uuids?count={count}")

    castError req
    return (await req.body).parseJson["uuids"].mapIt it.str

  proc getReshards*(self: CC or AsyncCC): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#reshard
    let req = await self.hc.get(fmt"{self.baseUrl}/_reshard")

    castError req
    return (await req.body).parseJson

  proc reshardState*(self: CC or AsyncCC): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-state
    let req = await self.hc.get(fmt"{self.baseUrl}/_reshard/state")

    castError req
    return (await req.body).parseJson

  proc changeReshardState*(self: CC or AsyncCC; state: ReshardStates, state_reason = "") {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#put--_reshard-state

    let req = await self.hc.put(fmt"{self.baseUrl}/_reshard/state", $ createNadd(
      %*{"state": $state},
      [state_reason],
      defaults
    ))
    castError req

  proc reshardJobs*(self: CC or AsyncCC; jobId = ""): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs-jobid
    let req = await self.hc.get(fmt"{self.baseUrl}/_reshard/jobs/" & jobId)

    castError req
    return (await req.body).parseJson

  proc createReshardJob*(self: CC or AsyncCC, db;
    `type`=  "split", 
    node,
    `range`, 
    shard,
    error = ""
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#post--_reshard-jobs

    let req = await self.hc.post(fmt"{self.baseUrl}/_reshard/jobs", $ createNadd( %* {
      "type": `type`,
      "db": db,
    }, [node, `range`, shard, error],
    defaults))

    castError req
    return (await req.body).parseJson

  proc deleteReshadJob*(self: CC or AsyncCC; jobId: string) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#delete--_reshard-jobs-jobid
    let req = await self.hc.delete(fmt"{self.baseUrl}/_reshard/jobs/{jobid}")
    castError req

  proc getReshardJobState*(self: CC or AsyncCC; jobId: string): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs-jobid-state
    let req = await self.hc.get(fmt"{self.baseUrl}/_reshard/jobs/{jobId}/state")
    castError req

    return (await req.body).parseJson

  proc changeReshardJobState*(self: CC or AsyncCC; jobId, state: string, state_reason = "") {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#put--_reshard-state

    let req = await self.hc.put(fmt"{self.baseUrl}/_reshard/jobs/{jobId}/state", $createNadd(
      %* {"state": state},
      [state_reason],
      defaults
    ))

    castError req

  proc getCurrentSession*(self: CC or AsyncCC): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/authn.html#get--_session
    let req = await self.hc.get(fmt"{self.baseUrl}/_session")

    castError req
    return (await req.body).parseJson

  proc cookieAuth*(self: CC or AsyncCC; name, password: string): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/authn.html#post--_session
    let req = await self.hc.post(fmt"{self.baseUrl}/_session", $ %* {
      "name": name,
      "password": password
    })

    castError req
    self.hc.headers.add "Cookie", req.headers["Set-Cookie"]

    return (await req.body).parseJson

  proc proxyAuth*(self: CC or AsyncCC; username, token: string, roles: seq[string])=
    ## https://docs.couchdb.org/en/latest/api/server/authn.html?highlight=authentication#proxy-authentication
    self.hc.headers["X-Auth-CouchDB-Roles"] = roles.join ","
    self.hc.headers["X-Auth-CouchDB-UserName"] = username
    self.hc.headers["X-Auth-CouchDB-Token"] = token

  proc jwtAuth*(self: CC or AsyncCC; token: string)=
    ## https://docs.couchdb.org/en/latest/api/server/authn.html?highlight=authentication#jwt-authentication
    self.hc.headers["Authorization"] = "Bearer " & token

  proc removeAuth*(self: CC or AsyncCC)=
    for k in ["Cookie", "Authorization", 
      "X-Auth-CouchDB-Roles", "X-Auth-CouchDB-UserName", "X-Auth-CouchDB-Token"]:
      
      del self.hc.headers, k

  proc getNodeConfig*(self: CC or AsyncCC, node): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config
    let req = await self.hc.get(fmt"{self.baseUrl}/_node/{node}/_config")

    castError req
    return (await req.body).parseJson

  proc getNodeSectionConfig*(self: CC or AsyncCC, node, section; ): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#node-node-name-config-section
    let req = await self.hc.get(fmt"{self.baseUrl}/_node/{node}/_config/{section}")

    castError req
    return (await req.body).parseJson

  proc getNodeSectionKeyConfig*(self: CC or AsyncCC, node, section; key: string): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config-section-key
    let req = await self.hc.get(fmt"{self.baseUrl}/_node/{node}/_config/{section}/{key}")

    castError req
    return (await req.body).parseJson

  proc updateNodeSectionKeyConfig*(self: CC or AsyncCC, node, section; key: string, newval: JsonNode): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config-section-key
    let req = await self.hc.put(fmt"{self.baseUrl}/_node/{node}/_config/{section}/{key}", $ newval)
    castError req
    return (await req.body).parseJson

  proc deleteNodeSectionKeyConfig*(self: CC or AsyncCC, node, section; key: string): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#delete--_node-node-name-_config-section-key
    let req = await self.hc.delete(fmt"{self.baseUrl}/_node/{node}/_config/{section}/{key}")
    castError req
    return (await req.body).parseJson

  proc reloadConfigs*(self: CC or AsyncCC, node) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config-section-key
    let req = await self.hc.post(fmt"{self.baseUrl}/_node/{node}/_config/_reload")
    castError req

  # DATEBASE API ------------------------------------------------------------

  proc isDBexists*(self: CC or AsyncCC, db): Future[bool] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/common.html#head--db
    let req = await self.hc.head(fmt"{self.baseUrl}/{db}")
    return req.code == Http200

  proc getDBinfo*(self: CC or AsyncCC, db): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/common.html#get--db
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}")

    castError req
    return (await req.body).parseJson

  proc createDB*(self: CC or AsyncCC, db; q, n = -1, partitioned = false) {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#put--db
    let req = await self.hc.put(fmt"{self.baseUrl}/{db}?" & encodeQuery createNadd(
      newseq[DoubleStrTuple](),
      [q, n, partitioned],
      defaults
    ))

    castError req

  proc deleteDB*(self: CC or AsyncCC, db) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#delete--db
    let req = await self.hc.delete(fmt"{self.baseUrl}/{db}")

    castError req

  proc createDoc*(self: CC or AsyncCC, db; doc: JsonNode, batch = BVNon): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#post--db

    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/?" & encodeQuery createNadd(
      newseq[DoubleStrTuple](),
      [batch],
      defaults
    ), $doc)

    castError req
    return (await req.body).parseJson

  proc designDocs*(self: CC or AsyncCC, db;
    conflicts,
    descending = false,
    startkey,
    endkey = "",
    startkey_docid,
    endkey_docid = "",
    include_docs = false,
    inclusive_end = true,
    key = "",
    keys = newseq[string](),
    limit,
    skip = 0,
    update_seq = false,
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-design-docs

    let queryParams = createNadd(newseq[DoubleStrTuple](), [
      conflicts,
      descending,
      startkey,
      endkey,
      startkey_docid,
      endkey_docid,
      include_docs,
      inclusive_end,
      key,
      limit,
      skip,
      update_seq,
    ], defaults)

    let
      url = fmt"{self.baseUrl}/{db}/_design_docs/?" & encodeQuery(queryParams)
      req =
        if keys == defaults.keys:
          await self.hc.get(url)
        else:
          await self.hc.post(url, $ %*{"keys": keys})

    castError req
    return (await req.body).parseJson

  proc bulkGet*(self: CC or AsyncCC, db; docs: JsonNode, revs = false): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-bulk-get
    doAssert docs.kind == JArray

    let req = await self.hc.post(
      fmt"{self.baseUrl}/{db}/_bulk_get?" & encodeQuery createNadd(
        newseq[DoubleStrTuple](),
        [revs],
        defaults
    ), $ %*{"docs": docs})

    castError req
    return (await req.body).parseJson

  proc bulkDocs*(self: CC or AsyncCC, db; docs: JsonNode, new_edits = true): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-bulk-docs
    doAssert docs.kind == JArray

    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_bulk_docs", $createNadd(
      %* {"docs": docs},
      [new_edits],
      defaults
    ))

    castError req
    return (await req.body).parseJson

  proc find*(self: CC or AsyncCC, db; mangoQuery: JsonNode, 
    explain = false
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/find.html#db-find
    ## https://docs.couchdb.org/en/latest/api/database/find.html#post--db-_explain
    ## https://docs.couchdb.org/en/latest/api/partitioned-dbs.html#db-partition-partition-id-find
    ## https://docs.couchdb.org/en/latest/api/partitioned-dbs.html#db-partition-partition-id-explain

    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/" & (
      if explain: "_explain"
      else: "_find"
    ), $mangoQuery)

    castError req
    return (await req.body).parseJson

  proc createIndex*(self: CC or AsyncCC, db;
    index: JsonNode,
    ddoc,
    name,
    `type` = "",
    partitioned = false
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/find.html#db-index
    doAssert index.kind == JObject

    let req = await self.hc.post(
      fmt"{self.baseUrl}/{db}/_index",
      $createNadd(%* {"index": index}, [
        ddoc,
        name,
        `type`,
        partitioned
      ], defaults))

    castError req
    return (await req.body).parseJson

  proc getIndexes*(self: CC or AsyncCC, db): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/find.html#get--db-_index
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_index")

    castError req
    return (await req.body).parseJson

  proc deleteIndex*(self: CC or AsyncCC, db, ddoc; name: string) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/find.html#delete--db-_index,ddoc;json-name
    let req = await self.hc.delete(fmt"{self.baseUrl}/{db}/_index/{ddoc}/json/{name}")
    castError req

  proc getshards*(self: CC or AsyncCC, db): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/shard.html
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_shards")

    castError req
    return (await req.body).parseJson

  proc shardsDoc*(self: CC or AsyncCC, db, docId): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/shard.html#db-shards-doc
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_shards/{docid}")

    castError req
    return (await req.body).parseJson

  proc syncShards*(self: CC or AsyncCC, db) {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/shard.html#db-sync-shards
    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_sync_shards")

    castError req

  proc changes*(self: CC or AsyncCC, db; feed: FeedVariants,
    doc_ids = newseq[string](),
    conflicts,
    descending = false,
    filter = "",
    heartbeat = 60000,
    include_docs,
    attachments,
    att_encoding_info = false,
    `last-event-id` = 0,
    limit = 0,
    since = "now",
    style: StyleVariants = SVMainOnly,
    timeout = -1,
    view = "",
    seq_interval = 0,
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/changes.html
    var queryParams = @[("feed", $feed)].createNadd([
      conflicts,
      descending,
      filter,
      heartbeat,
      include_docs,
      style,
      attachments,
      att_encoding_info,
      `last-event-id`,
      limit,
      since,
      timeout,
      view,
      seq_interval,
    ], defaults)

    let url = fmt"{self.baseUrl}/{db}/_changes?" & encodeQuery(queryParams)
    let req =
      if docids.len != 0:
        await self.hc.post(url, $ %* {"doc_ids": docids})
      else:
        await self.hc.get(url)

    castError req
    return (await req.body).parseJson

  proc compact*(self: CC or AsyncCC, db) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/compact.html#db-compact
    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_compact")

    castError req

  proc compactDesignDoc*(self: CC or AsyncCC, db, ddoc) {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/compact.html#db-compact-design-doc
    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_compact/{ddoc}")

    castError req

  proc viewCleanup*(self: CC or AsyncCC, db) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/compact.html#db-view-cleanup
    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_view_cleanup")

    castError req

  proc getSecurity*(self: CC or AsyncCC, db): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/security.html#get--db-_security
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_security")

    castError req
    return (await req.body).parseJson

  proc setSecurity*(self: CC or AsyncCC, db; admins, members: JsonNode) {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/security.html#put--db-_security
    let req = await self.hc.put(fmt"{self.baseUrl}/{db}/_security", $ %* {
      "admins": admins,
      "members": members,
    })

    castError req

  proc purge*(self: CC or AsyncCC, db; obj: JsonNode): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#db-purge
    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_purge", $ obj)

    castError req
    return (await req.body).parseJson

  proc getPurgedInfosLimit*(self: CC or AsyncCC, db): Future[int] {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#get--db-_purged_infos_limit
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_purged_infos_limit")

    castError req
    return (await req.body).strip.parseInt

  proc setPurgedInfosLimit*(self: CC or AsyncCC, db; limit: int) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#put--db-_purged_infos_limit
    let req = await self.hc.put(fmt"{self.baseUrl}/{db}/_purged_infos_limit", $limit)

    castError req

  proc missingRevs*(self: CC or AsyncCC, db; obj: JsonNode): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#db-missing-revs
    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_missing_revs", $ obj)

    castError req
    return (await req.body).parseJson["missing_revs"]

  proc revsDiff*(self: CC or AsyncCC, db; obj: JsonNode): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#post--db-_revs_diff
    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_revs_diff", $ obj)

    castError req
    return (await req.body).parseJson

  proc getRevsLimit*(self: CC or AsyncCC, db): Future[int] {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#get--db-_revs_limit
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_revs_limit")

    castError req
    return (await req.body).strip.parseInt

  proc setRevsLimit*(self: CC or AsyncCC, db; limit: int) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#put--db-_revs_limit
    let req = await self.hc.put(fmt"{self.baseUrl}/{db}/_revs_limit", $limit)

    castError req

  # DOCUMENTs API & LOCAL DOCUMENTs API ---------------------------------------------------
  proc getLocalDocs*(self: CC or AsyncCC, db;
    conflicts,
    descending = false,
    startkey,
    endkey = "",
    startkey_docid,
    endkey_docid = "",
    include_docs = false,
    inclusive_end = true,
    key = "",
    keys = newseq[string](),
    limit,
    skip = 0,
    update_seq = false,
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/local.html#db-local-docs

    let req = await self.hc.post(fmt"{self.baseUrl}/{db}/_local_docs/", $ createNadd( %* {}, [
      conflicts,
      descending,
      startkey,
      endkey,
      startkey_docid,
      endkey_docid,
      include_docs,
      inclusive_end,
      key,
      limit,
      skip,
      update_seq,
    ], defaults))

    castError req
    return (await req.body).parseJson

  ## for local APIs, append `doc_id` to`_local` : "_local/{doc_id}"
  proc getDoc*(self: CC or AsyncCC, db, docid; rev="", headOnly: bool = false,
    attachments,
    att_encoding_info = false,
    atts_since = newseq[string](),
    conflicts,
    deleted_conflicts = false,
    latest,
    local_seq,
    meta = false,
    open_revs = newseq[string](),
    revs,
    revs_info = false
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/document/common.html#get--db-docid
    ## https://docs.couchdb.org/en/latest/api/document/common.html#head--db-docid
    ## https://docs.couchdb.org/en/latest/api/local.html#get--db-_local-docid
    var queryParams = newseq[DoubleStrTuple]().createNadd([
      attachments,
      att_encoding_info,
      atts_since,
      conflicts,
      deleted_conflicts,
      latest,
      local_seq,
      meta,
      open_revs,
      rev,
      revs,
      revs_info,
    ], defaults)

    let req = await self.hc.request(
      fmt"{self.baseUrl}/{db}/{docid}?" & encodeQuery(queryParams),
      httpMethod =
        if headOnly: HttpHead
        else: HttpGet
      )

    castError req

    return 
      if headOnly: %* {}
      else: (await req.body).parseJson

  proc createOrUpdateDoc*(self: CC or AsyncCC, db, docid; rev: string, obj: JsonNode): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/document/common.html#put--db-docid
    ## https://docs.couchdb.org/en/latest/api/local.html#put--db-_local-docid
    let req = await self.hc.put(fmt"{self.baseUrl}/{db}/{docid}?rev={rev}", $obj)

    castError req
    return (await req.body).parseJson

  proc deleteDoc*(self: CC or AsyncCC, db, docid; rev: string, batch = BVNon, new_edits = false) {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/document/common.html#delete--db-docid
    ## https://docs.couchdb.org/en/latest/api/local.html#delete--db-_local-docid
    var queryParams = @[("rev", rev)].createNadd([batch, new_edits], defaults)
    let req = await self.hc.delete(fmt"{self.baseUrl}/{db}/{docid}?" & encodeQuery(queryParams))

    castError req

  # FIXME httpclient dosen't support custom httpmethod
  #[
    proc copyDoc*(self: CC or AsyncCC, db, docid; destination: string,
      rev = "",
      batch = BVNon
    ): Future[JsonNode] {.captureDefaults, multisync.} =
      ## https://docs.couchdb.org/en/latest/api/document/common.html#copy--db-docid
      ## https://docs.couchdb.org/en/latest/api/local.html#copy--db-_local-docid
      var queryParams = newseq[DoubleStrTuple]().createNadd([rev, batch], defaults)

      let req = await self.hc.request(
        fmt"{self.baseUrl}/{db}/{docid}?" & encodeQuery(queryParams),
        httpMethod = "COPY", # compiler complains about deprecation
        headers = changeHeaders(self.hc.headers, [("Destination", destination)])
      )

      castError req
      return (await req.body).parseJson
  ]#

  proc getDocAtt*(self: CC or AsyncCC, db, docid, attname;
    headOnly = false,
    rev = ""
  ): Future[Attachment] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#head--db-docid-attname
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#get--db-docid-attname
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#head--db-_design-ddoc-attname
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#get--db-_design-ddoc-attname

    var queryParams = newseq[DoubleStrTuple]().createNadd([rev], defaults)

    let req = await self.hc.request(
      fmt"{self.baseUrl}/{db}/{docid}/{attname}?" & encodeQuery(queryParams),
      httpMethod =
      if headOnly: HttpHead
        else: HttpGet
      )

    castError req
    return Attachment(
      contentEncoding: req.headers.getOrDefault("Content-Encoding"),
      etag: req.headers["ETag"],
      content: await req.body)

  proc uploadDocAtt*(self: CC or AsyncCC, db, docid, attname;
    contentType,
    content: string,
    rev = ""
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#put--db-docid-attname
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#put--db-_design-ddoc-attname
    var queryParams = newseq[DoubleStrTuple]().createNadd([rev], defaults)

    let req = await self.hc.request(
      fmt"{self.baseUrl}/{db}/{docid}/{attname}?" & encodeQuery(queryParams),
      httpMethod = HttpPut,
      headers = changeHeaders(self.hc.headers, [
        ("Content-Type", contentType),
        ("Content-Length", $content.len)
      ]),
      body = content 
    )

    castError req
    return (await req.body).parseJson

  proc deleteDocAtt*(self: CC or AsyncCC, db, docid, attname; rev: string, batch = BVNon): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#delete--db-docid-attname
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#delete--db-_design-ddoc-attname

    var queryParams = @[("rev", rev)].createNadd([batch], defaults)
    let req = await self.hc.delete(fmt"{self.baseUrl}/{db}/{docid}/{attname}?" & encodeQuery(queryParams))

    castError req
    return (await req.body).parseJson

  # DESIGN DOCUMENTs API ------------------------------------------------------------

  proc getDesignDoc*(self: CC or AsyncCC, db, ddoc; headOnly:bool = false): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#head--db-_design-ddoc

    let req = await self.hc.request(
      fmt"{self.baseUrl}/{db}/_design/{ddoc}",
      httpMethod =
      if headOnly: HttpHead
        else: HttpGet
    )

    castError req

    return
      if headOnly:
        %* {}
      else:
        (await req.body).parseJson

  proc createOrUpdateDesignDoc*(self: CC or AsyncCC, db, ddoc; rev="", language= "javascript",
    filters= newJObject(),
    options= newJObject(),
    updates= newJObject(),
    validate_doc_update= "",
    views = newJObject(),
    autoupdate = true,
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#put--db-_design-ddoc
      
    var query = %*{"language": language}
    if rev != "": query["_rev"] = % rev
    
    let req = await self.hc.put(fmt"{self.baseUrl}/{db}/_design/{ddoc}", $createNadd(query,
      [
        filters,
        options,
        updates,
        validate_doc_update,
        views,
        autoupdate,
      ],
      defaults))

    castError req
    return (await req.body).parseJson

  proc deleteDesignDoc*(self: CC or AsyncCC, db, ddoc; rev:string) {.multisync.} =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#delete--db-_design-ddoc

    let req = await self.hc.delete(fmt"{self.baseUrl}/{db}/_design/{ddoc}?rev={rev}")
    castError req

  proc getDesignDocInfo*(self: CC or AsyncCC, db, ddoc): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#get--db-_design-ddoc-_info

    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_info")

    castError req
    return (await req.body).parseJson

  proc getViewImpl(self: CC or AsyncCC; url: string, obj: JsonNode): Future[JsonNode] {.multisync.}=
    let req = await self.hc.post(
        if "queries" in obj and obj["queries"].kind == JArray: url & "/queries"
        else: url,
      $obj)

    castError req
    return (await req.body).parseJson

  proc getView*(self: CC or AsyncCC, db, ddoc, view; queryObj: JsonNode): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/ddoc/views.html#get--db-_design-ddoc-_view-view
    ## https://docs.couchdb.org/en/latest/api/partitioned-dbs.html#db-partition-partition-design-design-doc-view-view-name
    return await self.getViewImpl(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_view/{view}", queryObj)
  
  proc allDocs*(self: CC or AsyncCC, db; queryObj: JsonNode): Future[JsonNode] {.captureDefaults, multisync.}=
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#post--db-_all_docs
    ## https://docs.couchdb.org/en/latest/api/partitioned-dbs.html#get--db-_partition-partition-_all_docs
    return await self.getViewImpl(fmt"{self.baseUrl}/{db}/_all_docs", queryObj)

  proc searchByIndex*(self: CC or AsyncCC, db, ddoc; index: string,
    query: string,
    bookmark = "",
    counts = newJObject(),
    drilldown = newjObject(),
    group_field = "",
    group_sort = newjObject(),
    highlight_fields = newjObject(),
    highlight_pre_tag = "",
    highlight_post_tag = "",
    highlight_number = 0,
    highlight_size = 0,
    include_docs = false,
    include_fields = newJObject(),
    limit = 0,
    ranges = newJObject(),
    sort = newJobject(),
    stale = "",
  ): Future[JsonNode] {.captureDefaults, multisync.} =
    ## https://docs.couchdb.org/en/latest/api/ddoc/search.html#get--db-_design-ddoc-_search-index
    var queryParams = @[("query", query)].createNadd([
      bookmark,
      counts,
      drilldown,
      group_field,
      group_sort,
      highlight_fields,
      highlight_pre_tag,
      highlight_post_tag,
      highlight_number,
      highlight_size,
      include_docs,
      include_fields,
      limit,
      ranges,
      sort,
      stale,
    ], defaults)
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_search/{index}?" &
        encodeQuery(queryParams))

    castError req
    return (await req.body).parseJson

  proc searchInfo*(self: CC or AsyncCC, db, ddoc; index: string): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/ddoc/search.html#get--db-_design-ddoc-_search_info-index
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_search_info/{index}")

    castError req
    return (await req.body).parseJson

  proc execUpdateFunc*(self: CC or AsyncCC, db, ddoc; `func`: string,
    body: JsonNode = newJNull(),
    docid = "",
  ): Future[tuple[body, id, rev: string]] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/ddoc/render.html#post--db-_design-ddoc-_update-func
    ## https://docs.couchdb.org/en/latest/api/ddoc/render.html#put--db-_design-ddoc-_update-func-docid
    
    let req = await self.hc.request(
      fmt"{self.baseUrl}/{db}/_design/{ddoc}/_update/{`func`}/{docid}",
      body = $body,
      httpMethod = 
        if docid == "": HttpPost
        else: HttpPut
    )

    castError req

    return (
      (await req.body),
      $req.headers["X-Couch-Id"],
      $req.headers["X-Couch-Update-Newrev"]
    )

  # partitioned DATABASEs API ------------------------------------------------------------
  # FIXME add better api for partions for all docs and getview
  proc getPartitionInfo*(self: CC or AsyncCC, db, partition): Future[JsonNode] {.multisync.}=
    ## https://docs.couchdb.org/en/latest/api/partitioned-dbs.html#get--db-_partition-partition
    let req = await self.hc.get(fmt"{self.baseUrl}/{db}/_partition/{partition}")

    castError req
    return (await req.body).parseJson
