## this file is based on following link from CouchDB documentations:
## https://docs.couchdb.org/en/latest/ddocs/ddocs.html#design-documents

import macros, json, tables
import macroutils except name


type
  MapFun* =
    proc(doc: JsonNode): seq[JsonNode] {.nimcall.}

  ReduceFun* =
    proc(keysNids: seq[JsonNode], values: seq[JsonNode], rereduce: bool): JsonNode {.nimcall.}

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
  updateFuncs*: FuncStore[UpdateFun]
  filterFuncs*: FuncStore[Filterfun]
  validateFuncs*: FuncStore[ValidateFun]

# ------------------------------------------------

template prepare {.dirty.}=
  expectKind body, {nnkProcDef, nnkFuncDef}
  let fname = body.name

template patternError {.dirty.} =
  raise newException(ValueError, "not exists")

# ------------------------------------------------  

macro mapfun*(body)=
  prepare
  
  superQuote:
    `body`
    
    when `fname` is MapFun:
      mapFuncs[`fname.strval`] = `fname`
    else:
      patternError      

macro redfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is ReduceFun:
      reduceFuncs[`fname.strval`] = `fname`
    else:
      patternError

macro updatefun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is UpdateFun:
      updateFuncs[`fname.strval`] = `fname`
    else:
      patternError

macro filterfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is Filterfun:
      filterFuncs[`fname.strval`] = `fname`
    else:
      patternError

macro validatefun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fname` is ValidateFun:
      validateFuncs[`fname.strval`] = `fname`
    else:
      patternError