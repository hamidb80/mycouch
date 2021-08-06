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
  let pr = startProcess("./tests/temp.exe")
  
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
      check recv.parseJson[1][0].elems == (v.mapIt it[2])

  test "rereduce":
    var allVals: seq[JsonNode]
    for k, v in grouped:
      allVals.add v

    send  %*["rereduce", ["testReduce"],  allVals]
    check recv.parseJson == %*[true, [nil]]

  test "ddoc::new":
    send [
      "ddoc",
      "new",
      "_design/temp",
      {
        "_id": "_design/temp",
        "_rev": "8-d7379de23a751dc2a19e5638a7bbc5cc",
        "language": "nim",
        "updates": {
          "doubleTheNamePlusBody": "name-x2"
        },
        "filters": {
          "myFilter": "isWomen"
        },
        "validate_doc_update": "remainTheSameType",
      }
    ]

    check recv == "true"

  test "ddoc::updates":
    send [
      "ddoc",
      "_design/temp",
      [
        "updates",
        "doubleTheNamePlusBody"
      ],
      [
        {
          "name": "hamid"
        },
        {
          "method": "POST",
          "raw_path": "/test/_design/1139/_update/nothing",
          "headers": {
            "Accept": "*/*",
            "Accept-Encoding": "identity, gzip, deflate, compress",
            "Content-Length": "0",
            "Host": "localhost:5984"
          },
          "body": "-s",
        }
      ]
    ]

    let res = recv.parseJson
    check:
      res[1]["name"].str == "hamidhamid-s"
      res[2] == %*{"body": "yay"}

  test "ddoc::filters":
    send [
      "ddoc",
      "_design/temp",
      [
        "filters",
        "myFilter"
      ],
      [
        [
          {
            "name": "hamid",
            "gender": "male"
          },
          {
            "name": "mahdie",
            "gender": "female"
          },
        ],
        {
          "method": "POST",
          "raw_path": "/test/_design/1139/_update/nothing",
          "headers": {
            "Accept": "*/*",
            "Accept-Encoding": "identity, gzip, deflate, compress",
            "Content-Length": "0",
            "Host": "localhost:5984"
          },
          "body": "-s",
        }
      ]
    ]

    check recv.parseJson == %* [true, [false, true]]
    
  test "ddoc::validatefun":
    send [
      "ddoc",
      "_design/temp",
      [ "validate_doc_update" ],
      [
        { "type": 2 },
        { "type": false },
        {
            "name": "Admin",
            "roles": ["admin"]
        },
        {
            "admins": {},
            "members": []
        }
      ]
    ]

    check recv.parseJson == %*{"forbidden": "not a specefic reason"}

    # ---------------------------------------

    send [
      "ddoc",
      "_design/temp",
      [ "validate_doc_update" ],
      [
        { "type": "a string" },
        { "type": "another string" },
        {
            "name": "Admin",
            "roles": ["admin"]
        },
        {
            "admins": {},
            "members": []
        }
      ]
    ]
    
    check recv == "1"
    

  pr.terminate