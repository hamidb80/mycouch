import 
  json, tables

## this file is based on following link from CouchDB documentations:
## https://docs.couchdb.org/en/latest/ddocs/ddocs.html#design-documents

# -------------------------------------------------------

type
  MapResult* = Table[JsonNode, seq[JsonNode]]
  MapFun* = 
    proc(doc: JsonNode): void {.nimcall.}

  ReduceFun* = 
    proc(keys,  values: JsonNode, rereduce=false): JsonNode {.nimcall.}

  UpdateFun* = 
    proc(doc,req: JsonNode): tuple[newDoc:JsonNode, response: string] {.nimcall.}

  Filterfun* =
    proc(doc,req: JsonNode): bool {.nimcall.}

  Forbidden*    = object of Defect
  Unauthorized* = object of Defect

  ValidateFun* = 
    proc(newDoc, oldDoc, userCtx, secObj: JsonNode): bool {.nimcall.}

# -------------------------------------------------------

var mapResult: MapResult
proc emit(key: JsonNode, val= newJNull())=
  if key in mapResult:
    mapResult[key].add val
  else:
    mapResult[key] = @[val]

# -------------------------------------------------------

proc myMapFunc(doc: JsonNode)=
  emit(doc["key"])
