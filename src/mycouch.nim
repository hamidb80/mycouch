import 
  httpclient, 
  json, tables, strformat

type
  CouchDBClient = object
    hc: HttpClient
    baseUrl: string

using
  self: CouchDBClient

# initiate -----------------------------------------------

proc newCouchDBClient*(host: string = "http://localhost",
    port = 5984): CouchDBClient =
  let client = newHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})

  CouchDBClient(hc: client, baseUrl: fmt"{host}:{port}")

proc login*(self; name, pass: string) =
  let resp = self.hc.post(fmt"{self.baseUrl}/_session", $ %*{
    "name": name, "password": pass
  })
  assert resp.code == Http200
  assert resp.headers.table.hasKey "set-cookie"

  #  if stores like this: @["AuthSession=<CODE>; Version=N; Expires=<WEEK_DAY>, <DATE> GMT; Max-Age=600; Path=/; HttpOnly"]
  self.hc.headers.table["Cookie"] = resp.headers.table["set-cookie"]

# -----------------------------------------------------------------

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

proc updateDoc*(self; dbName: string; doc: JsonNode):JsonNode =
  assert (doc.hasKey "_id") and (doc.hasKey "_rev"), "doc must have '_id' & '_rev'"

  let resp = self.hc.put(fmt"{self.baseUrl}/{dbName}/", $doc)
  assert resp.code == Http200

  resp.body.parseJson

proc deleteDoc*(self; dbName: string; id, rev:string):JsonNode =
  let resp = self.hc.delete(fmt"{self.baseUrl}/{dbName}/{id}?rev={rev}")

  assert resp.code == Http200

  resp.body.parseJson

proc bulkInsert*(self; dbName: string; docs: openArray[JsonNode]): JsonNode =
  let resp = self.hc.post(fmt"{self.baseUrl}/{dbName}/", $docs)

  assert resp.code == Http201

  resp.body.parseJson

proc bulkUpdate*(self; dbName: string; docs: openArray[JsonNode]):JsonNode =
  # assert (doc.hasKey "_id") and (doc.hasKey "_rev"), "doc must have '_id' & '_rev'"

  let resp = self.hc.put(fmt"{self.baseUrl}/{dbName}/", $docs)
  assert resp.code == Http200

  resp.body.parseJson