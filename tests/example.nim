import json, sequtils
import mycouch, mycouch/queryGen

when isMainModule:
  let cdb = newCouchDBClient()

  discard cdb.cookieAuthenticate("admin", "admin")
  # echo cdb.getCurrentSession.pretty

  # echo cdb.find("movie", mango(
  #   selector = PS(@artist == "mohammadAli"),
  # )).pretty

  # echo cdb.getDoc("movie", "6832dc85678d4d03ee2f41b4490010f9").pretty
  # echo cdb.alldbs()

  let jobIds= cdb.reshardJobs["jobs"].mapIt it["id"].str
  for jid in jobids:
    cdb.deleteReshadJob(jid)