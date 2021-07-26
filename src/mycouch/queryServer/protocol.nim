## https://docs.couchdb.org/en/latest/query-server/protocol.html

import json, sequtils, strformat
import designDocuments

var
  mapFunc: MapFun
  reduceFunc: ReduceFun
  rereduceFunc: RereduceFun
  updateFunc: UpdateFun
  filterFunc: Filterfun
  validateFunc: ValidateFun

proc dataProcessor(command: string, args: seq[JsonNode]): JsonNode =
  case command:
  of "reset":
    % true

  of "map_doc":
    let doc = args[1]
    %* [doc.mapFunc]

  of "reduce":
    let docs = args[1].getElems

    %* [true, [docs.reduceFunc]]

  of "rereduce":
    let values = args[1].getElems

    %* [true, [values.rereduceFunc]]

  of "ddoc":
    if args[0] == %"new": return % true

    let 
      id = args[0].str
      subCommand = args[1][0].str
      funcname = args[1][1].str
      myArgs = args[2].getElems

    case subCommand:

    of "updates":
      let updated = updateFunc(myArgs[0], myArgs[1])
      %* ["up", updated.newDoc, updated.response]

    of "filters":
      %* [true, myArgs[0].mapIt filterFunc(it, myArgs[1])]

    of "views":
      let docs = args[2]
      %* [true, myArgs[0].mapIt it.mapFunc.len != 0]

    of "validate_doc_update":
      let
        newDoc = args[0]
        oldDoc = args[1]
        req = args[2]
        sec = args[3]

      validateFunc(newDoc, oldDoc, req, sec)
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
      echo (%*["error", $e.name, $e.msg])
