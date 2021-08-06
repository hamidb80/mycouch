## https://docs.couchdb.org/en/latest/query-server/protocol.html

import json, sequtils, tables, strformat
import designDocuments


type
  Ddoc = object
    updates: Table[string, string]
    filters: Table[string, string]
    mapper: string
    validator: string

var 
  selectedMapFunc: MapFun
  ddocs: Table[string, Ddoc]

# -------------------------------------------------

template throw(msg: string)=
  raise newException(ValueError, msg)

# -------------------------------------------------

proc dataPipeline(command: string, args: seq[JsonNode]): JsonNode {.inline.}=

  case command:
  of "reset":
    selectedMapFunc = nil
    % true

  of "add_fun":
    let fname = args[0].str

    if fname notin mapFuncs:
      # couchdb 3.1.1 sends reduce function to find out it can be compiled by query server or not
      # currently it is not documented, i asked the commiunity
      if fname in reduceFuncs: 
        return % true

      throw "func with name '" & fname & "' does not exist"

    selectedMapFunc = mapFuncs[fname]
    % true

  of "map_doc":
    let doc = args[0]
    %* [selectedMapFunc(doc)]

  of "reduce":
    let
      fname = args[0][0].str 
      docs = args[1].getElems # seq of  [[key, id-of-doc], value]
    
    var 
      values: seq[JsonNode]
      keysNids: seq[JsonNode]

    for d in docs:
      keysNids.add d[0]
      values.add d[1]

    %* [true, [reduceFuncs[fname](keysNids, values, false)]]

  of "rereduce":
    let
      fname = args[0][0].str 
      values = args[1].getElems

    %* [true, [reduceFuncs[fname](@[], values, true)]]

  of "ddoc":
    if args[0] == %"new": 
      let 
        ddocId = args[1].str
        ddocObj = args[2]
      
      ddocs[ddocId] = Ddoc()

      if "filters" in ddocObj:
        for name, src in ddocObj["filters"]:
          ddocs[ddocId].filters[name] = src.str

      if "updates" in ddocObj:
        for name, src in ddocObj["updates"]:
          ddocs[ddocId].updates[name] = src.str

      ddocs[ddocId].mapper = ddocObj.getOrDefault("view").getOrDefault("map").getStr("")
      ddocs[ddocId].validator = ddocObj.getOrDefault("validate_doc_update").getStr("")

      return % true

    let 
      ddocid = args[0].str
      subCommand = args[1][0].str
      funcname = 
        if args[1].len == 2: args[1][1].str
        else: ""
      myArgs = args[2].getElems

    case subCommand:

    of "updates":
      let updated = updateFuncs[ddocs[ddocid].updates[funcname]](myArgs[0], myArgs[1])
      %* ["up", updated.newDoc, updated.response]

    of "filters":
      let fn = filterFuncs[ddocs[ddocid].filters[funcname]]
      %* [true, myArgs[0].mapIt fn(it, myArgs[1])]

    of "views":
      let fn = mapFuncs[ddocs[ddocid].mapper]
      %* [true, myArgs.mapIt fn(it).len != 0]

    of "validate_doc_update":
      let
        newDoc = myArgs[0]
        oldDoc = myArgs[1]
        req = myArgs[2]
        sec = myArgs[3]

        fn = validateFuncs[ddocs[ddocid].validator]
      
      fn(newDoc, oldDoc, req, sec)
      % 1

    else:
      raise newException(ValueError, fmt"subcommand ddoc.'{subCommand}' is not supported by mycouch")

  else:
    raise newException(ValueError, fmt"command '{command}' is not supported by mycouch")


proc run*()=
  while true:
    echo:
      try:
        let data = parseJson stdin.readLine
        dataPipeline(data[0].str, data.getElems[1..^1])

      except Forbidden as e:
        %*{"forbidden": e.msg}

      except Unauthorized as e:
        %*{"unauthorized": e.msg}

      except:
        let e = getCurrentException()
        %*["error", $e.name, e.msg]
