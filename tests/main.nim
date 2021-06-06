import json
import mycouch, queryGen

when isMainModule:
  let cdb = newCouchDBClient()
  cdb.login "admin", "admin"

  let query = mango:
    query: @artist == "mohammadAli"
    fields: ["artist", "genre"]
    limit: 100

  echo cdb.find("movie", query).pretty