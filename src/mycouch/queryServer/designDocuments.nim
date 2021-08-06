## this file is based on following link from CouchDB documentations:
## https://docs.couchdb.org/en/latest/ddocs/ddocs.html#design-documents

import macros, json, tables, strformat, sequtils, strutils
import macroutils except name


type
  MapFun* =
    proc(doc: JsonNode): seq[JsonNode] {.nimcall.}

  ReduceFun* =
    proc(keysNids: seq[JsonNode], values: seq[JsonNode], rereduce: bool): JsonNode {.nimcall.}

  UpdateFun* =
    proc(doc, req: JsonNode): tuple[newDoc, response: JsonNode] {.nimcall.}

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

  let 
    fident = body[0]
    fname = 
      if body[0].kind == nnkIdent:
        body[0].strVal
      else: # nnkAccQouted
        body[0].mapIt(it.strVal).join "" # support for quoted names

macro patternError(fname: string, collection: typedesc)=
  error fmt"proc with name '{fname}' can't be matched with pattern '{$collection}'"

# ------------------------------------------------  

macro mapfun*(body)=
  prepare
  
  superQuote:
    `body`
    
    when `fident` is MapFun:
      mapFuncs[`fname.strval`] = `fident`
    else:
      patternError `fname.strval`, MapFunc


macro redfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fident` is ReduceFun:
      reduceFuncs[`fname.strval`] = `fident`
    else:
      patternError `fname.strval`, ReduceFun

macro updatefun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fident` is UpdateFun:
      updateFuncs[`fname.strval`] = `fident`
    else:
      patternError `fname.strval`, UpdateFun

macro filterfun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fident` is Filterfun:
      filterFuncs[`fname.strval`] = `fident`
    else:
      patternError `fname.strval`, Filterfun

macro validatefun*(body)=
  prepare
  
  superQuote:
    `body`
    when `fident` is ValidateFun:
      validateFuncs[`fname.strval`] = `fident`
    else:
      patternError `fname.strval`, ValidateFun
