## https://docs.couchdb.org/en/latest/query-server/protocol.html

import json, sequtils, tables, strformat
import designDocuments


template throw(msg: string)=
  raise newException(ValueError, msg)

template checkFuncExistance(name: string, collection: untyped)=
  if name notin collection:
    throw "func with name '" & name & "' does not exist"

type
  Ddoc = object
    updates: Table[string, string]
    filters: Table[string, string]
    mapper: string
    validator: string

var 
  selectedMapFunc: MapFun
  ddocs: Table[string, Ddoc]

proc dataProcessor(command: string, args: seq[JsonNode]): JsonNode =
  case command:
  of "reset":
    selectedMapFunc = nil
    % true

  of "add_fun":
    let fname = args[1].str
    checkFuncExistance fname, mapFuncs
    
    selectedMapFunc = mapFuncs[fname]
    % true

  of "map_doc":
    let doc = args[1]
    %* [selectedMapFunc(doc)]

  of "reduce":
    let
      fname = args[0][0].str 
      docs = args[1].getElems

    %* [true, [reduceFuncs[fname](docs)]]

  of "rereduce":
    let
      fname = args[0][0].str 
      values = args[1].getElems

    %* [true, [rereduceFuncs[fname](values)]]

  of "ddoc":
    if args[0] == %"new": 
      let 
        ddocName = args[1].str
        ddocObj = args[2]
      
      ddocs[ddocname] = Ddoc()

      if "filters" in ddocObj:
        for name, src in ddocObj["filters"]:
          ddocs[ddocname].filters.add name, src.str

      if "updates" in ddocObj:
        for name, src in ddocObj["updates"]:
          ddocs[ddocname].updates.add name, src.str

      ddocs[ddocname].mapper = ddocObj.getOrDefault("view").getOrDefault("map").getStr("")
      ddocs[ddocname].validator = ddocObj.getOrDefault("validate_doc_update").getStr("")

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
      %* [true, myArgs.mapIt fn(it, myArgs[1])]

    of "views":
      let fn = mapFuncs[ddocs[ddocid].mapper]
      %* [true, myArgs.mapIt fn(it).len != 0]

    of "validate_doc_update":
      let
        newDoc = myArgs[0]
        oldDoc = myArgs[1]
        req = myArgs[2]
        sec = myArgs[3]

        fn = validateFuncs[funcname]
      
      fn(newDoc, oldDoc, req, sec)
      % 1

    else:
      raise newException(ValueError, fmt"subcommand ddoc.'{subCommand}' is not supported")

  else:
    raise newException(ValueError, fmt"command '{command}' is not supported")


proc run*()=
  while true:
    try:
      let data = parseJson stdin.readLine
      echo dataProcessor(data[0].str, data.getElems[1..^1])

    except Forbidden as e:
      echo %*{"forbidden": e.msg}

    except Unauthorized as e:
      echo %*{"unauthorized": e.msg}

    except Exception as e:
      echo %*["error", $e.name, $e.msg]
