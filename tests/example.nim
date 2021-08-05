import unittest, httpclient, threadpool, json, sequtils
import mycouch/[queryGen, api]

when isMainModule:
  let cdb = newCouchDBClient()

  discard cdb.cookieAuthenticate("admin", "admin")
  echo cdb.getCurrentSession.pretty

  echo cdb.find("movies", mango(
    selector = PS(@artist == "mohammadAli"),
  )).pretty

  # echo cdb.getDoc("movies", "6832dc85678d4d03ee2f41b4490010f9").pretty
  # echo cdb.alldbs()


  # let jobIds= cdb.reshardJobs["jobs"].mapIt it["id"].str
  # for jid in jobids:
  #   cdb.deleteReshadJob(jid)

  echo "---------------------------"

  echo cdb.hc.getContent("http://google.com/")

  try:
    let dbChangeFeed = spawn cdb.DBupdates(FVLongPoll)
    cdb.createDB("dsadasd")
    
    echo (^dbChangeFeed).pretty
  except CouchDBError as e:
    echo e.info