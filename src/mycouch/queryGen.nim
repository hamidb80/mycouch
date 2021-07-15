import
  macros, macroutils,
  json, strformat, strutils, sequtils
import ./private/utils

func parseIdent(exp: NimNode): NimNode =
  if exp.kind == nnkPrefix:
    assert exp[0].strVal == "@"

    if exp[1].kind == nnkAccQuoted:
      #[
        AccQuoted
          Ident "friend"
          Ident "."
          Ident "name"
        
        => "friend.name"
      ]#
      return (exp[1].mapIt it.strVal).join.newStrLitNode
    else:
      return exp[1].strVal.newStrLitNode

  elif exp.kind == nnkIdent:
    return exp

  else:
    raise newException(ValueError, fmt"unexpected NimNode '{exp.kind}' as an ident")

#TODO: add type assersions

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
  limit: Natural = 25,
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
  (%*{
    "selector": selector,
  }).createNadd([
    fields,
    sort,
    limit,
    skip,
    use_index,
    conflicts,
    r,
    bookmark,
    update,
    stable,
    execution_stats,
  ], mangoDefaults)
