## this file is based on following link from CouchDB documentations:
## https://docs.couchdb.org/en/latest/ddocs/ddocs.html#design-documents

import json, tables


type
  MapFun* =
    proc(doc: JsonNode): seq[JsonNode] {.nimcall.}

  ReduceFun* =
    proc(mappedDocs: seq[JsonNode]): JsonNode {.nimcall.}

  RereduceFun* =
    proc(values: seq[JsonNode]): JsonNode {.nimcall.}

  UpdateFun* =
    proc(doc, req: JsonNode): tuple[newDoc: JsonNode, response: string] {.nimcall.}

  Filterfun* =
    proc(doc, req: JsonNode): bool {.nimcall.}

  Forbidden* = object of Defect
  Unauthorized* = object of Defect

  ValidateFun* =
    proc(newDoc, oldDoc, req, sec: JsonNode) {.nimcall.}

# -------------------------------------------------------

proc log*(msg: string) =
  echo %["log", msg]

template emit*(key: JsonNode, val = newJNull()) =
  result.add( %* [key, val])