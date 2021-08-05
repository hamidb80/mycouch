import
  macros, macroutils,
  json, strformat
import api, ./private/utils

func parseIdent(exp: NimNode): NimNode =
  case exp.kind:
  of nnkPrefix:
    case exp[0].strVal:
    of "@":
        exp[1].strVal.newStrLitNode
    of "@-":
        ("_" & exp[1].strVal).newStrLitNode
    else:
      raise newException(ValueError, fmt"the perfix '{exp[0].strval}' is not supported for fieldnames")
  
  of nnkIdent:
    exp
  else:
    raise newException(ValueError, fmt"unexpected NimNode '{exp.kind}' as an ident")

func parse(exp: NimNode): NimNode =
  case exp.kind:
  of nnkInfix:
    var
      op = exp[0].strVal # operator
      br1 = exp[1]       # branch1
      br2 =
        if exp.len == 3: parse exp[2]
        else: newEmptyNode()

    case op:
    of "and", "or":
      # TODO flattenDeepInfix
      op = "$" & op # $and , $or
      return superQuote: {
        `op`: [`br1.parse`, `br2.parse`]
      }
    of "<": op = "$lt"
    of "<=": op = "$lte"
    of ">=": op = "$gte"
    of ">": op = "$gt"
    of "==": op = "$eq"
    of "!=": op = "$ne"
    of "=~": op = "$regex"
    of "in": op = "$in"
    of "notin": op = "$nin"
    of "is":
      op = "$type"

      let strRepr = br2.repr
      var temp =
        case strRepr:
        of "object", "array", "string", "number": strRepr
        of "nil": "null"
        of "bool": "boolean"
        else: ""

      if temp != "":
        br2 = newStrLitNode temp
    of "mod":
      op = "$mod"

      if br2.kind == nnkBracket:
        doAssert br2.len == 2, "mod shoud be like [Divisor, Remainder]"
    else:
      raise newException(ValueError, fmt"infix '{op}' is not defiend")

    return superQuote: {
      `br1.parseIdent`: {
        `op`: `br2.parse`
      }
    }
  of nnkPrefix:
    let op = exp[0].strVal

    case op:
    of "@":
      return exp.parseIdent
    of "not":
      return superQuote: {
        "$not": `exp[1].parse`
      }
    of "?", "!", "?=", "?!":
      let field = exp[1].parseIdent

      if op.len == 2:
        return quote: {
          `field`: {
            "$exists": `op` == "?="
          }
        }
      else:
        return quote: {
          `field`: {
            "$eq": `op` == "?"
          }
        }
    else:
      error fmt"prefix {op} is not defiend"
  of nnkCall:
    if exp[0].kind == nnkDotExpr:

      let
        firstParam = exp[0][0]
        fn = exp[0][1].strVal # function
        otherParams = exp[1..^1]

      case fn:
      of "size":
        return superQuote: {
          `firstParam.parseIdent`: {
            "$size": `otherParams[0]`
          }
        }
      of "nor":
        return superQuote: {
          "$nor": [`firstParam.parse`, `otherParams[0].parse`]
        }
      of "all":
        return superQuote: {
          `firstParam.parseIdent`: {
            "$all": `otherParams[0]`
          }
        }
      of "elemMatch", "allMatch", "keyMapMatch": #FIXME i don't know, maybe they want some specialixations
        let vfn = "$" & fn
        return superQuote: {
          `firstParam.parseIdent`: {
            `vfn`: `otherParams[0].parse`
          }
        }
      else:
        error fmt"function {fn} is not defined"
  of nnkPar:
    return exp[0].parse
  else:
    return exp

template PS*(body: untyped): untyped = parseSelector(body)
macro parseSelector*(body: untyped): JsonNode =
  var target =
    if body.kind == nnkStmtList: body[0]
    else: body

  return
    if target.kind == nnkNilLit: quote: %*{"_id": {"$gt": nil}}
    else: superQuote: %* `target.parse`

type sortObj* = tuple[field: string, order: string]
func `%`(so: sortObj): JsonNode =
  % [so.field, so.order]

proc mango*(
  selector: JsonNode,
  fields = newseq[string](),
  sort= newseq[sortObj](),
  limit: Natural = 0,
  skip: Natural = 0,
  use_index: string= "",
  use_indexes = newseq[string](),
  conflicts= false,
  r: Natural = 1,
  bookmark="null",
  update=true,
  stable=false,
  execution_stats: bool = false
): JsonNode {.captureDefaults.} =
  result = (%*{
    "selector": selector,
  }).createNadd([
    fields,
    sort,
    limit,
    skip,
    conflicts,
    r,
    bookmark,
    update,
    stable,
    execution_stats,
  ], defaults)

  if use_index != "":
    result["use_index"] = % use_index
  elif use_indexes.len != 0:
    result["use_index"] = % use_indexes


proc viewQuery*(
  conflicts = false,
  descending = false,
  startkey,
  endkey,
  startkey_docid,
  endkey_docid = newJObject(),
  group = false,
  group_level = -1,
  include_docs = false,
  attachments = false,
  att_encoding_info = false,
  inclusive_end = true,
  key = newJObject(),
  keys = newJObject(),
  limit = 0,
  reduce = true,
  skip = 0,
  sorted = true,
  stable = true,
  update = UVTrue,
  update_seq = false,
): JsonNode {.captureDefaults.}=
  createNadd(%*{}, [
    conflicts,
    descending,
    startkey,
    endkey,
    startkey_docid,
    endkey_docid,
    group,
    group_level,
    include_docs,
    attachments,
    att_encoding_info,
    inclusive_end,
    key,
    keys,
    limit,
    reduce,
    skip,
    sorted,
    stable,
    update,
    update_seq,
  ], defaults)
