import json
import mycouch, queryGen

when isMainModule:
  let cdb = newCouchDBClient()
  cdb.login "admin", "admin"

  echo cdb.find("movie", MangoQuery(
    selector= PS(@artist == "mohammadAli"),
    fields= @["artist", "genre"],
  )).pretty