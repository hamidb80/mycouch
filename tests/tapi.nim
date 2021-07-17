import unittest, json
import mycouch/api

func contains(json: JsonNode, keys: openArray[string]): bool =
  for k in keys:
    if k notin json:
      return false
  true

suite "server api":
  let cc = newCouchDBClient()
  discard cc.cookieAuthenticate("admin", "admin")

  test "serverInfo":
    let resp = cc.serverInfo()
    check ["couchdb", "version"] in resp

  test "activeTasks":
    let resp = cc.activeTasks()
    check resp.kind == JArray
    
  test "allDBs":
    let resp = cc.allDBs()
    check resp.len != 0