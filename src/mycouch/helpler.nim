import json, sequtils, httpcore
import api

# wrappers -----------------------------------------------------------

template cookieAuthWrapper*(attempts = 2, name,pass:string, self: CouchDBClient, body: untyped): untyped=
  for _ in 1..attempts:
    try: 
      body
    except CouchDBError e:
      if e.responseCode == Http401:
        discard self.cookieAuth(admin, pass)
        
# functionalities ----------------------------------------------------

proc deleteById*(self, db, docid)=
  let req = self.getDoc(db, docid)
  self.createOrUpdateDoc(db, docid, req["_rev"].str, %* {"_deleted": true})

proc bulkDelete*(self, db; docIds: seq[string]): JsonDocs=
  let query = % docsId.mapIt %* {"_id": it}
  docRevs = self.bulkGet(db, {"docs": query})["results"].mapIt %* { 
    "_id": it["id"], 
    "_rev": it["docs"][0]["ok"]["_rev"],
    "_deleted": true
  }

  self.bulkDocs(db, docsRev)
  
proc updateById(self,db, docid; newDoc: JsonNode): JsonDocs=
  let docrev = self.getDoc(db, docid)["_rev"]
  self.createOrUpdateDoc(db, docid, docrev, newDoc)

proc getNupdate*(self, db, docid: string, fn: proc(doc: JsonNode): JsonNode, docrev= ""): JsonNode=
  let req = self.getDoc(db, docid, docrev)
  self.createOrUpdateDoc(db, docid, req["_rev"].str, fn(req))
