import unittest, os, json
import mycouch/api


let 
  uname = getEnv "COUCHDB_ADMIN_NAME"
  upass = getEnv "COUCHDB_ADMIN_PASS"

if uname.len * upass.len == 0:
  quit("'COUCHDB_ADMIN_NAME' & 'COUCHDB_ADMIN_PASS' must be set")

suite "query server":
  let cc = newCouchDBClient()
  discard cc.cookieAuthenticate(uname, upass)

  const db = "mydb"
  cc.createDB(db)

  const dataset = parseJson readFile "../tests/dataset.json"
  discard cc.bulkDocs(db, dataset)

  
