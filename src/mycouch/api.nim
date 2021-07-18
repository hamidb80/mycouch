import
  httpclient, uri,
  json, tables, strformat, strutils, sequtils
import coverage
import ./private/[utils, exceptions]

type
  CouchDBClient* = object
    hc*: HttpClient
    baseUrl*: string

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

using
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
  var client = newHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})

  CouchDBClient(hc: client, baseUrl: fmt"{host}:{port}")

proc changeHeaders(
  lastHeaders: HttpHeaders,
  changedData: openArray[tuple[k: string, v: string]]
): HttpHeaders =
  result.deepcopy lastHeaders

  for (key, val) in changedData:
    result.add key, val

template castError*(res) = # res: Response
  if res.code.int >= 300: 
    raise newCouchDBError(res.code, res.body.parseJson)

# SERVER API ----------------------------------------------------------------------

addTestCov:
  proc serverInfo*(self): JsonNode=
    ## https://docs.couchdb.org/en/latest/api/server/common.html#api-server-root
    let req = self.hc.get(fmt"{self.baseUrl}/")

    castError req
    req.body.parseJson

  proc activeTasks*(self): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#active-tasks
    let req = self.hc.get(fmt"{self.baseUrl}/_active_tasks/")

    castError req
    req.body.parseJson

  proc allDBs*(self;
    descending = false,
    limit,
    skip = 0,
    startkey,
    endKey = newJObject()
  ): seq[string] {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#all-dbs

    var queryParams = @[
      ("descending", $descending),
      ("skip", $skip),
    ].createNadd([
      limit,
      startKey,
      endKey,
    ], defaults)

    let req = self.hc.get(fmt"{self.baseUrl}/_all_dbs/?" & encodeQuery(queryParams))

    castError req
    req.body.parseJson.mapIt it.str

  proc DBsInfo*(self; keys: openArray[string]): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#dbs-info

    let req = self.hc.post(fmt"{self.baseUrl}/_dbs_info", $ %*{"keys": keys})

    castError req
    req.body.parseJson

  ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_cluster_setup
  ## https://docs.couchdb.org/en/latest/api/server/common.html#post--_cluster_setup

  proc DBupdates*(self; feed: string, timeout = 60, heartbeat = 60000, since = ""): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#db-updates
    let req = self.hc.get(fmt"{self.baseUrl}/_db_updates/?" & encodeQuery([
      ("feed", feed),
      ("since", since),
      ("timeout", $timeout),
      ("heartbeat", $heartbeat)]
    ))

    castError req
    req.body.parseJson

  proc membership*(self): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#membership
    let req = self.hc.get(fmt"{self.baseUrl}/_membership")

    castError req
    req.body.parseJson

  proc replicate*(self;
    source,
    target: string,
    cancel,
    continuous,
    create_target = false,
    create_target_params: JsonNode = newJObject(),
    doc_ids = newseq[string](),
    filter: string = "",
    source_proxy,
    target_proxy: string = ""
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#replicate

    let req = self.hc.post(fmt"{self.baseUrl}/_replicate", $ createNadd( %* {
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
    req.body.parseJson

  proc schedulerJobs*(self; limit, skip = 0): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#scheduler-jobs

    let queryParams = newseq[DoubleStrTuple]().createNadd([
      limit,
      skip
    ], defaults)

    let req = self.hc.get(fmt"{self.baseUrl}/_all_dbs/?" & encodeQuery(queryParams))

    castError req
    req.body.parseJson

  proc schedulerDocs*(self; replicatorDB, doc_id = "", limit, skip = 0, ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#scheduler-docs
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_scheduler-docs-replicator_db
    let req = self.hc.get(
      fmt"{self.baseUrl}/_scheduler/docs" & (
        if replicatorDB != "": fmt"/{replicatorDB}"
        else:
          var queryParams = newseq[DoubleStrTuple]().createNadd([limit, skip], defaults)
          "?" & encodeQuery(queryParams)
    ))

    castError req
    req.body.parseJson

  proc schedulerDoc*(self, docid; replicatorDB: string): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_scheduler-docs-replicator_db-docid
    let req = self.hc.get(fmt"{self.baseUrl}/_scheduler/docs/{replicatorDB}/{docid}")

    castError req
    req.body.parseJson

  proc nodeInfo*(self, node): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
    let req = self.hc.get(fmt"{self.baseUrl}/_node/{node}")

    castError req
    req.body.parseJson

  proc nodeStats*(self, node): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
    let req = self.hc.get(fmt"{self.baseUrl}/_node/{node}/_stats")

    castError req
    req.body.parseJson

  proc nodeSystem*(self, node): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name
    let req = self.hc.get(fmt"{self.baseUrl}/_node/{node}/_system")

    castError req
    req.body.parseJson

  proc nodeRestart*(self, node): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#node-node-name-restart
    let req = self.hc.post(fmt"{self.baseUrl}/_node/{node}/_restart")

    castError req
    req.body.parseJson

  ## maybeTODO: https://docs.couchdb.org/en/latest/api/server/common.html#search-analyze

  proc up*(self, node): bool =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#up
    self.hc.get(fmt"{self.baseUrl}/_up").code == Http200 # or 404

  proc uuids*(self; count = 1): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#uuids
    let req = self.hc.get(fmt"{self.baseUrl}/_uuids?count={count}")

    castError req
    req.body.parseJson

  proc reshard*(self): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#reshard
    let req = self.hc.get(fmt"{self.baseUrl}/_reshard")

    castError req
    req.body.parseJson

  proc reshardState*(self): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-state
    let req = self.hc.get(fmt"{self.baseUrl}/_reshard/state")

    castError req
    req.body.parseJson

  type ReshardStates* = enum
    stopped = "stopped"
    running = "running"
  proc changeReshardState*(self; state: string, state_reason = "") {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#put--_reshard-state

    let req = self.hc.put(fmt"{self.baseUrl}/_reshard/state", $ createNadd(
      %*{"state": state},
      [state_reason],
      defaults
    ))
    castError req

  proc reshardJobs*(self; jobId = ""): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs-jobid
    let req = self.hc.get(fmt"{self.baseUrl}/_reshard/jobs/" & jobId)

    castError req
    req.body.parseJson

  proc createReshadJob*(self, db; `type`, node, `range`, shard,
      error = "") {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#post--_reshard-jobs

    let req = self.hc.post(fmt"{self.baseUrl}/_reshard/jobs", $ createNadd( %* {
      "type": `type`,
      "db": db,
    }, [node, `range`, shard, error],
    defaults))

    castError req

  proc deleteReshadJob*(self; jobId: string) =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#delete--_reshard-jobs-jobid
    let req = self.hc.post(fmt"{self.baseUrl}/_reshard/jobs/{jobid}")
    castError req

  proc reshadJobState*(self; jobId: string): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#get--_reshard-jobs-jobid-state
    let req = self.hc.get(fmt"{self.baseUrl}/_reshard/jobs/{jobId}/state")
    castError req

    req.body.parseJson

  proc changeReshardJobState*(self; jobId, state: string, state_reason = "") {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/server/common.html#put--_reshard-state

    let req = self.hc.put(fmt"{self.baseUrl}/_reshard/jobs/{jobId}/state", $createNadd(
      %* {"state": state},
      [state_reason],
      defaults
    ))

    castError req

  proc getCurrentSession*(self): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/authn.html#get--_session
    let req = self.hc.get(fmt"{self.baseUrl}/_session")

    castError req
    req.body.parseJson

  proc cookieAuthenticate*(self; name, password: string): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/authn.html#post--_session
    let req = self.hc.post(fmt"{self.baseUrl}/_session", $ %* {
      "name": name,
      "password": password
    })

    castError req
    self.hc.headers.add "Cookie", req.headers["Set-Cookie"]

    req.body.parseJson

  proc deleteCookieSession*(self) =
    ## https://docs.couchdb.org/en/latest/api/server/authn.html#delete--_session
    # FIXME also remove it from header
    let req = self.hc.delete(fmt"{self.baseUrl}/_session")

    castError req

  # TODO proxy-auth, jwf-auth

  proc getNodeConfig*(self, node): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config
    let req = self.hc.get(fmt"{self.baseUrl}/_node/{node}/_config")

    castError req
    req.body.parseJson

  proc getNodeSetionConfig*(self, node, section; ): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#node-node-name-config-section
    let req = self.hc.get(fmt"{self.baseUrl}/_node/{node}/_config/{section}")

    castError req
    req.body.parseJson

  proc getNodeSetionKeyConfig*(self, node, section; key: string): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config-section-key
    let req = self.hc.get(fmt"{self.baseUrl}/_node/{node}/_config/{section}/{key}")

    castError req

  proc updateNodeSetionKeyConfig*(self, node, section; key: string,
      newval: auto) =
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config-section-key
    let req = self.hc.put(fmt"{self.baseUrl}/_node/{node}/_config/{section}/{key}",
        $ % newval)
    castError req

  proc deleteNodeSetionKeyConfig*(self, node, section; key: string) =
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config-section-key
    let req = self.hc.delete(fmt"{self.baseUrl}/_node/{node}/_config/{section}/{key}")
    castError req

  proc reloadConfigs*(self, node) =
    ## https://docs.couchdb.org/en/latest/api/server/configuration.html#get--_node-node-name-_config-section-key
    let req = self.hc.post(fmt"{self.baseUrl}/_node/{node}/_config/_reload")
    castError req

  # DATEBASE API ------------------------------------------------------------

  proc isDBexists*(self, db): bool =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#head--db
    let req = self.hc.head(fmt"{self.baseUrl}/{db}")
    req.code == Http200

  proc getDBinfo*(self, db): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#get--db
    let req = self.hc.get(fmt"{self.baseUrl}/{db}")

    castError req
    req.body.parseJson

  proc createDB*(self, db; q, n = -1, partioned = false) {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#put--db
    let req = self.hc.put(fmt"{self.baseUrl}/{db}", encodeQuery createNadd(
      newseq[DoubleStrTuple](),
      [q, n, partioned],
      defaults
    ))

    castError req

  proc deleteDB*(self, db) =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#delete--db
    let req = self.hc.delete(fmt"{self.baseUrl}/{db}")

    castError req

  proc createDoc*(self, db; doc: JsonNode, batch = BVNon): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/database/common.html#post--db

    let req = self.hc.post(fmt"{self.baseUrl}/{db}/?" & encodeQuery createNadd(
      newseq[DoubleStrTuple](),
      [batch],
      defaults
    ), $doc)

    castError req
    req.body.parseJson

  proc allDocs*(self, db): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-all-docs
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_all_docs/")

    castError req
    req.body.parseJson

  proc allDocs*(self, db; keys: seq[string]): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#post--db-_all_docs
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_all_docs/", $ %*{"keys": keys})

    castError req
    req.body.parseJson

  proc designDocs*(self, db;
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
  ): JsonNode {.captureDefaults.} =
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
          self.hc.get(url)
        else:
          self.hc.post(url, $ %*{"keys": keys})

    castError req
    req.body.parseJson

  proc allDocs*(self, db; queries: JsonNode): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#post--db-_all_docs-queries
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_all_docs/queries", $queries)

    castError req
    req.body.parseJson

  proc bulkGet*(self, db; docs: JsonNode, revs = false): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-bulk-get
    let req = self.hc.post(
      fmt"{self.baseUrl}/{db}/_bulk_get?" & encodeQuery createNadd(
        newseq[DoubleStrTuple](),
        [revs],
        defaults
    ), $docs)

    castError req
    req.body.parseJson

  proc bulkDocs*(self, db; docs: JsonNode, new_edits = true): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/database/bulk-api.html#db-bulk-docs
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_bulk_docs", $createNadd(
      %* {"docs": docs},
      [new_edits],
      defaults
    ))

    castError req
    req.body.parseJson

  proc find*(self, db;
    selector: JsonNode,
    limit = 0,
    skip = 0,
    sort = newJObject(),
    fields = newseq[string](),
    use_index = "",
    use_indexes = newseq[string](),
    conflicts = false,
    r = 1,
    bookmark = "",
    update = true,
    stable = false,
    execution_stats = false
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/database/find.html#db-find
    var body = (%{"selector": selector}).createNadd([
      limit,
      skip,
      sort,
      fields,
      conflicts,
      r,
      bookmark,
      update,
      stable,
      execution_stats,
    ], defaults)

    if use_index != "":
      body["use_index"] = % use_index
    elif use_indexes.len != 0:
      body["use_index"] = % use_indexes

    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_find", $body)

    castError req
    req.body.parseJson

  proc createIndex*(self, db;
    index: JsonNode,
    ddoc,
    name,
    `type` = "",
    partitioned = false
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/database/find.html#db-index
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_index", $createNadd( %* {}, [
      ddoc,
      name,
      `type`,
      partitioned
    ], defaults))

    castError req
    req.body.parseJson

  proc getIndexes*(self, db): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/find.html#get--db-_index
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_index")

    castError req
    req.body.parseJson

  proc deleteIndex*(self, db, ddoc; name: string) =
    ## https://docs.couchdb.org/en/latest/api/database/find.html#delete--db-_index,ddoc;json-name
    let req = self.hc.delete(fmt"{self.baseUrl}/{db}/_index/{ddoc}/json/{name}")
    castError req

  proc explain*(self, db): JsonNode =
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_explain")

    castError req
    req.body.parseJson

  proc shards*(self, db): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/shard.html
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_shards")

    castError req
    req.body.parseJson

  proc shardsDoc*(self, db, docId): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/shard.html#db-shards-doc
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_shards/{docid}")

    castError req
    req.body.parseJson

  proc syncShards*(self, db, docId): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/shard.html#db-sync-shards
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_sync_shards")

    castError req
    req.body.parseJson

  proc changes*(self, db;
      handleChanges: proc(data: JsonNode),
      doc_ids = newseq[string](),
      conflicts,
      descending = false,
      feed,
      filter = "",
      heartbeat = 60000,
      include_docs,
      attachments,
      att_encoding_info = false,
      `last-event-id` = 0,
      limit = 1,
      since = 0,
      style: string,
      timeout = 60000,
      view = "",
      seq_interval = 0,
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/database/shard.html#db-sync-shards
    var queryParams = newseq[DoubleStrTuple]().createNadd([
      conflicts,
      descending,
      feed,
      filter,
      heartbeat,
      include_docs,
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
        self.hc.post(url, $ %* {"doc_ids": docids})
      else:
        self.hc.get(url)

    # FIXME
    castError req
    req.body.parseJson

  proc compact*(self, db): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/compact.html#db-compact
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_compact")

    castError req
    req.body.parseJson

  proc compactDesignDoc*(self, db, ddoc): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/compact.html#db-compact-design-doc
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_compact/{ddoc}")

    castError req
    req.body.parseJson

  proc viewCleanup*(self, db): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/compact.html#db-view-cleanup
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_view_cleanup")

    castError req
    req.body.parseJson

  proc getSecurity*(self, db): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/security.html#get--db-_security
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_security")

    castError req
    req.body.parseJson

  proc setSecurity*(self, db; admins, members: JsonNode): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/security.html#put--db-_security
    let req = self.hc.put(fmt"{self.baseUrl}/{db}/_security", $ %* {
      "admins": admins,
      "members": members,
    })

    castError req
    req.body.parseJson

  proc purge*(self, db; obj: JsonNode): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#db-purge
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_security", $ obj)

    castError req
    req.body.parseJson

  proc getPurgedInfosLimit*(self, db): int =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#get--db-_purged_infos_limit
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_purged_infos_limit")

    castError req
    req.body.parseInt

  proc setPurgedInfosLimit*(self, db; limit: int) =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#put--db-_purged_infos_limit
    let req = self.hc.put(fmt"{self.baseUrl}/{db}/_purged_infos_limit", $limit)

    castError req

  proc revsDiff*(self, db; obj: JsonNode): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#db-missing-revs
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_revs_diff", $ obj)

    castError req
    req.body.parseJson

  proc getRevsLimit*(self, db): int =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#get--db-_revs_limit
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_revs_limit")

    castError req
    req.body.parseInt

  proc setRevsLimit*(self, db; limit: int) =
    ## https://docs.couchdb.org/en/latest/api/database/misc.html#put--db-_revs_limit
    let req = self.hc.put(fmt"{self.baseUrl}/{db}/_revs_limit", $limit)

    castError req

  # DOCUMENTs API & LOCAL DOCUMENTs API ---------------------------------------------------

  proc getLocalDocs*(self, db;
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
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/local.html#db-local-docs

    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_design_docs/", $ createNadd( %* {}, [
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
    req.body.parseJson

  ## to local API, append `doc_id` to`_local` : "_local/{doc_id}"

  proc getDoc*(self, db, docid; headOnly: static[bool] = false,
    attachments,
    att_encoding_info = false,
    atts_since = newseq[string](),
    conflicts,
    deleted_conflicts = false,
    latest,
    local_seq,
    meta = false,
    open_revs = newseq[string](),
    all = false,
    rev = "",
    revs,
    revs_info = false
  ): JsonNode {.captureDefaults.} =
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

    if all:
      queryParams.add ("open_revs", "all")

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/{docid}?" & encodeQuery(queryParams),
      httpMethod =
      if headOnly: HttpHead
        else: HttpGet
      )

    castError req
    req.body.parseJson

  proc createOrUpdateDoc*(self, db, docid; obj: JsonNode): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/document/common.html#put--db-docid
    ## https://docs.couchdb.org/en/latest/api/local.html#put--db-_local-docid
    let req = self.hc.put(fmt"{self.baseUrl}/{db}/{docid}", $obj)

    castError req
    req.body.parseJson

  proc deleteDoc*(self, db, docid; rev: string, batch = BVNon, new_edits = false) {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/document/common.html#delete--db-docid
    ## https://docs.couchdb.org/en/latest/api/local.html#delete--db-_local-docid
    var queryParams = newseq[DoubleStrTuple]().createNadd([batch, new_edits], defaults)
    let req = self.hc.delete(fmt"{self.baseUrl}/{db}/{docid}?" & encodeQuery(queryParams))

    castError req

  proc copyDoc*(self, db, docid;
    destination: string,
    rev = "",
    batch = BVNon
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/document/common.html#copy--db-docid
    ## https://docs.couchdb.org/en/latest/api/local.html#copy--db-_local-docid
    var queryParams = newseq[DoubleStrTuple]().createNadd([rev, batch], defaults)

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/{docid}?" & encodeQuery(queryParams),
      httpMethod = "COPY",
      headers = changeHeaders(self.hc.headers, [("Destination", destination)])
    )

    castError req
    req.body.parseJson

  proc getDocAtt*(self, db, docid, attname;
    headOnly: static[bool] = false,
    rev = ""
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#head--db-docid-attname
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#get--db-docid-attname
    var queryParams = newseq[DoubleStrTuple].createNadd([rev], defaults)

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/{docid}/{attname}?" & encodeQuery(queryParams),
      httpMethod =
      if headOnly: HttpHead
        else: HttpGet
      )

    castError req
    req.body.parseJson

  proc uploadDocAtt*(self, db, docid, attname;
    contentType,
    content: string,
    rev = ""
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#put--db-docid-attname
    var queryParams = newseq[DoubleStrTuple]().createNadd([rev], defaults)

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/{docid}/{attname}?" & encodeQuery(queryParams),
      httpMethod = HttpPut,
      headers = changeHeaders(self.hc.headers, [
        ("Content-Type", contentType),
        ("Content-Length", $content.len)
      ]),
      body = content 
    )

    castError req
    req.body.parseJson

  proc deleteDocAtt*(self, db, docid; rev: string, batch = BVNon) {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/document/attachments.html#delete--db-docid-attname

    var queryParams = @[("rev", rev)].createNadd([batch], defaults)
    let req = self.hc.delete(fmt"{self.baseUrl}/{db}/{docid}?" & encodeQuery(queryParams))

    castError req

  # DESIGN DOCUMENTs API ------------------------------------------------------------

  proc getDesignDoc*(self, db, ddoc; headOnly: static[bool] = false): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#head--db-_design-ddoc

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/_design/{ddoc}",
      httpMethod =
      if headOnly: HttpHead
        else: HttpGet
    )

    castError req
    req.body.parseJson

  proc createOrUpdateDesignDoc*(self, db;
    ddoc: string,
    language: string,
    options: JsonNode,
    filters: seq[string],
    updates: JsonNode,
    validate_doc_update: string,
    views: JsonNode,
    autoupdate = true,
  ): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#put--db-_design-ddoc
    let req = self.hc.put(fmt"{self.baseUrl}/{db}/_design/{ddoc}")

    castError req
    req.body.parseJson

  proc deleteDesignDoc*(self, db, ddoc) =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#delete--db-_design-ddoc

    let req = self.hc.delete(fmt"{self.baseUrl}/{db}/_design/{ddoc}")
    castError req

  proc copyDesignDoc*(self, db, ddoc): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#copy--db-_design-ddoc

    let req = self.hc.request(fmt"{self.baseUrl}/{db}/_design/{ddoc}",
        httpMethod = "COPY")

    castError req
    req.body.parseJson

  proc getDesignDocAtt*(self, db, ddoc, attname;
    headOnly: static[bool] = false,
    rev = ""
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#head--db-_design-ddoc-attname
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#get--db-_design-ddoc-attname
    var queryParams = newseq[DoubleStrTuple].createNadd([rev], defaults)

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/{ddoc}/{attname}?" & encodeQuery(queryParams),
      httpMethod =
      if headOnly: HttpHead
        else: HttpGet
      )

    castError req
    req.body.parseJson

  proc uploadDesignDocAtt*(self, db, ddoc, attname; contentType, content: string, rev = "") {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#put--db-_design-ddoc-attname
    var queryParams = newseq[DoubleStrTuple]().createNadd([rev], defaults)

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/{ddoc}/{attname}?" & encodeQuery(queryParams),
      httpMethod = HttpPut,
      headers = changeHeaders(self.hc.headers, [
        ("Content-Type", content),
        ("Content-Length", $content.len)
      ])
    )

    castError req

  proc deleteDesignDocAtt*(self, db, ddoc; rev: string) {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#delete--db-_design-ddoc-attname
    let req = self.hc.delete(fmt"{self.baseUrl}/{db}/{ddoc}?rev={rev}")
    castError req

  proc getDesignDocInfo*(self, db, ddoc): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/ddoc/common.html#get--db-_design-ddoc-_info

    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_info")

    castError req
    req.body.parseJson

  proc getView*(self, db, ddoc, view;
    conflicts = false,
    descending = false,
    startkey,
    endkey,
    startkey_docid,
    endkey_docid = newJObject(),
    group = false,
    group_level = -1,
    include_docs = false,
    attachments = false,
    att_encoding_info = false,
    inclusive_end = true,
    key = newJObject(),
    keys = newJObject(),
    limit = 0,
    reduce = true,
    skip = 0,
    sorted = true,
    stable = true,
    update = UVTrue,
    update_seq = false,
  ): JsonNode {.captureDefaults.} =
    ## https://docs.couchdb.org/en/latest/api/ddoc/views.html#get--db-_design-ddoc-_view-view
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_view/{view}", $createNadd(%*{}, [
      conflicts,
      descending,
      startkey,
      endkey,
      startkey_docid,
      endkey_docid,
      group,
      group_level,
      include_docs,
      attachments,
      att_encoding_info,
      inclusive_end,
      key,
      keys,
      limit,
      reduce,
      skip,
      sorted,
      stable,
      update,
      update_seq,
    ], defaults))

    castError req
    req.body.parseJson

  proc getView*(self, db, ddoc, view; queries: JsonNode): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/ddoc/views.html#get--db-_design-ddoc-_view-view
    let req = self.hc.post(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_view/{view}", $
        %* {"queries": queries})
    castError req

    req.body.parseJson

  proc searchByIndex*(self, db, ddoc; index: string,
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
  ): JsonNode {.captureDefaults.} =
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
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_search/{index}?" &
        encodeQuery(queryParams))

    castError req
    req.body.parseJson

  proc searchInfo*(self, db, ddoc; index: string): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/ddoc/search.html#get--db-_design-ddoc-_search_info-index
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_design/{ddoc}/_search_info/{index}")

    castError req
    req.body.parseJson

  proc execUpdateFunc*(self, db, ddoc; `func`: string,
    body: JsonNode = newJNull(),
    docid = ""
  ): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/ddoc/render.html#post--db-_design-ddoc-_update-func
    ## https://docs.couchdb.org/en/latest/api/ddoc/render.html#put--db-_design-ddoc-_update-func-docid

    let req = self.hc.request(
      fmt"{self.baseUrl}/{db}/_design/{ddoc}/_update/{`func`}/{docid}",
      body = $body,
      httpMethod = (
        if docid == "": HttpPost
      else: HttpPut
    ))

    castError req
    req.body.parseJson

  # PARTIONED DATABASEs API ------------------------------------------------------------

  proc getPartitionInfo*(self, db, partition): JsonNode =
    ## https://docs.couchdb.org/en/latest/api/partitioned-dbs.html#get--db-_partition-partition
    let req = self.hc.get(fmt"{self.baseUrl}/{db}/_partition/{partition}")

    castError req
    req.body.parseJson

  ## https://docs.couchdb.org/en/latest/api/partitioned-dbs.html#get--db-_partition-partition-_all_docs