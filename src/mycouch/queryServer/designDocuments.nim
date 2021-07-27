## this file is based on following link from CouchDB documentations:
## https://docs.couchdb.org/en/latest/ddocs/ddocs.html#design-documents

import macros, json, tables
import macroutils except name


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

# ----------------------------------------------

type
  FuncStore[Fn] = Table[string, Fn]


var
  mapFuncs*: FuncStore[MapFun]
  reduceFuncs*: FuncStore[ReduceFun]
  rereduceFuncs*: FuncStore[RereduceFun]
  updateFuncs*: FuncStore[UpdateFun]
  filterFuncs*: FuncStore[Filterfun]
  validateFuncs*: FuncStore[ValidateFun]

# ------------------------------------------------

template prepare {.dirty.}=
  expectKind body, {nnkProcDef, nnkFuncDef}
  let fname = body.name

template patternError {.dirty.} =
  error "pattern mismatch"

# ------------------------------------------------  

macro mapfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is MapFun:
      mapFuncs.add `fname.strval`, `fname`
    else:
      patternError

macro redfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is ReduceFun:
      reduceFuncs.add `fname.strval`, `fname`
    else:
      patternError

macro reredfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is RereduceFun:
      rereduceFuncs.add `fname.strval`, `fname`
    else:
      patternError

macro updatefun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is UpdateFun:
      updateFuncs.add `fname.strval`, `fname`
    else:
      patternError

macro filterfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is Filterfun:
      filterFuncs.add `fname.strval`, `fname`
    else:
      patternError

macro validatefun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is ValidateFun:
      validateFuncs.add `fname.strval`, `fname`
    else:
      patternError