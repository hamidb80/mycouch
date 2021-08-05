import unittest, os, osproc, streams, tables, sequtils, json

template groupItBy[K, V](s: typed, keyExpr, valExpr: untyped): untyped=
  var result: Table[K, seq[V]]
  for it {.inject.} in s:
    let k = keyExpr
    if k in result:
      result[k].add valExpr
    else:
      result[k] = @[valExpr]

  result


suite "query server":
  let pr = startProcess("./tests/queryServerInstance.exe")
  
  template send(obj: untyped)=
    pr.inputStream.writeLine($ %* obj)
  
  template recv: untyped =
    pr.outputStream.readLine

  test "reset":
    send ["reset"]
    check (recv) == "true"

  test "add fun":
    send ["add_fun", "testMap"]
    check (recv) == "true"

  var reduced: seq[tuple[key, docid, res:JsonNode]]
  test "map doc":
    let movieList = parseJson readFile "./tests/assets/dataset.json"
    for movie in movieList:
      send ["map_doc", movie]
      
      let res = (parseJson recv)[0]
      for r in res:
        doAssert r.kind == JArray
        doAssert r.len == 2
        
        reduced.add (r[0], movie["_id"], r[1])

  var grouped: Table[JsonNode, seq[JsonNode]]
  test "reduce":
    grouped = groupItBy[JsonNode, JsonNode](reduced, it[0], %*[it[0], it[1], it[2]])

    for k, v in grouped:
      send  %*["reduce", ["testReduce"], v.mapIt %*[[it[0], it[1]], it[2]] ]
      check recv.parseJson[0].elems == (v.mapIt it[2])

  test "rereduce":
    var allVals: seq[JsonNode]
    for k, v in grouped:
      allVals.add v

    send  %*["rereduce", ["testReduce"],  allVals]
    check recv.parseJson == %*[true, nil]

  test "ddoc":
    discard

  pr.terminate