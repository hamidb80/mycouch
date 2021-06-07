import
  macros, macroutils,
  json, strformat, strutils, sequtils

func parse(exp: NimNode): NimNode =
  case exp.kind:
  of nnkInfix:
    var
      op = exp[0].strVal  # operator
      br1 = parse exp[1] # branch1
      br2 =
        if exp.len == 3: parse exp[2]
        else: newEmptyNode()

    case op:
    of "and", "or":
      op = "$" & op # $and , $or
      return quote: {
        `op`: [`br1`, `br2`]
      }

    of "<": op = "$lt"
    of "<=": op = "$lte"
    of ">=": op = "$gte"
    of ">": op = "$gt"
    of "==": op = "$eq"
    of "!=": op = "$ne"

    of "~=":
      # TODO regex
      op = "$regex"

    of "in":
      # TODO assert following type is openArray or bracket
      op = "$in"
    of "notin":
      op = "$nin"

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

      #TODO assert that ident is stringy type

    of "mod":
      op = "$mod"

      if br2.kind == nnkBracket:
        doAssert br2.len == 2, "mod shoud be like [Divisor, Remainder]"

      #TODO: assert ident type is openarray
    else: raise newException(ValueError, fmt"infix '{op}' is not defiend")

    doAssert br1.kind == nnkPrefix
    doAssert br1[0].strVal == "@"

    #TODO: support dyanmic field name

    return superQuote: {
      `br1[1].parse`: {
        `op`: `br2.parse`
      }
    }
  of nnkPrefix:
    let op = exp[0].strVal

    if op == "@": return exp
    elif op == "not": 
      return superQuote: {
        "$not": `exp[1].parse`
      }
    elif op notin ["?=", "?!"]: error fmt"prefix {op} is not defiend"

    let field = exp[1][1].strVal
    return quote: {
      `field`: {
        "$exists": `op` == "?="
      }
    }
  of nnkCall:
    if exp[0].kind == nnkDotExpr:
      assert exp[0][0].kind == nnkPrefix

      let 
        field = exp[0][0][1].strVal 
        fn = exp[0][1].strVal
        parameter = 
          if exp.len == 2: exp[1]
          else: nil

      case fn:
      of "size":
        return quote: {
          `field`: {
            "$size": `parameter`
          }
        }
      else: 
        error fmt"function {fn} is not defined"

    # TODO:
    # $all
    # $elemMatch
    # $allMatch
    # $keyMapMatch
  of nnkPar:
    return exp[0].parse
  of nnkAccQuoted:
    #[
      AccQuoted
        Ident "friend"
        Ident "."
        Ident "name"
      
      => "friend.name"
    ]#
    return (exp.mapIt it.strVal).join 
  else:
    return exp

template PS*(exp: untyped): untyped = parseSelector(exp)
macro parseSelector*(exp: untyped): JsonNode =
  var target =
   if exp.kind == nnkStmtList: exp[0]
   else: exp

  return
    if target.kind == nnkNilLit: quote: %*{"_id" : {"$gt": nil}}
    else: superQuote: %* `target.parse`

type sortObj* = tuple[field:string, order: string]
func `%`(so: sortObj): JsonNode=
  % [so.field, so.order]

func MangoQuery*(
  selector: JsonNode,
  fields:  seq[string],
  sort: seq[sortObj] = @[],
  limit: Natural = 25,
  skip: Natural = 0,
  execution_stats: bool = false
): JsonNode =
  %* {
    "selector": selector,
    "fields": fields,
    "sort": sort,
    "limit": limit,
    "execution_stats": execution_stats,
  }
