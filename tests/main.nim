import json
import mycouch, mycouch/queryGen

when isMainModule:
  let cdb = newCouchDBClient()
  cdb.login "admin", "admin"

  echo cdb.find("movie", mango(
    selector= PS(@artist == "mohammadAli"),
    fields= @["artist", "genre"],
  )).pretty

  echo cdb.alldbs()