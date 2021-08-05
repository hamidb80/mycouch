import unittest, httpclient, json, sequtils
import mycouch/[queryGen, api]

when isMainModule:
  let cc = newCouchDBClient()

  discard cc.cookieAuthenticate("admin", "admin")
  # echo cc.getCurrentSession.pretty

  # echo cc.find("movies", mango(
  #   selector = PS(@artist == "mohammadAli"),
  # )).pretty

  # echo cc.getDoc("movies", "6832dc85678d4d03ee2f41b4490010f9").pretty
  # echo cc.alldbs()

  # let jobIds= cc.reshardJobs["jobs"].mapIt it["id"].str
  # for jid in jobids:
  #   cc.deleteReshadJob(jid)

  # discard  cc.bulkDocs("movies", parseJson readFile "./tests/assets/dataset.json")
  let query = PS:
    nil
  
  echo cc.find("movies", mango(query))