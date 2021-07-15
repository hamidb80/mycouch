import 
  macros, 
  json
import macroutils, macroplus

type DoubleStrTuple* = tuple[key: string, val: string]

func getRealName(n: NimNode): string =
  case n.kind:
  of nnkPostfix: n[1].strval
  of nnkIdent: n.strval
  else:
    raise newException(ValueError, "not")

macro captureDefaults*(routine): untyped =
  ## this macro captures all default valued arguments and save them in a let defaults: tulple[arg1: defaultVal, arg2: ...,]
  ## in the head of the routine

  routine.expectKind RoutineNodes

  # let defaults = (a:2, b:3)
  #
  # LetSection:
  #   IdentDef:
  #     Ident "defaults"
  #     Empty
  #     TupleConstr:
  #       ExprColonExpr:
  #         Ident "a"
  #         IntLit 2
  #       ExprColonExpr:
  #         Ident "b"
  #         IntLit 3

  var defs = newLetStmt(
    ident(routine[RoutineName].getRealName & "Defaults"), 
    newnimNode(nnkTupleConstr)
  )

  for arg in routine[RoutineFormalParams][FormalParamsArguments]:
    if arg[IdentDefDefaultVal].kind != nnkEmpty:
      for ident in arg[IdentDefNames]:
        defs[0][IdentDefDefaultVal].add newNimNode(nnkExprColonExpr).add(
          ident, 
          arg[IdentDefDefaultVal]
        )
  
  return newStmtList(defs, routine)

func getStrName(n: NimNode): string=
  case n.kind:
  of nnkident: n.strVal
  of nnkAccQuoted: n[0].strVal
  else:
    raise newException(ValueError, "not allowed")


macro addIfIsNotDefault*(acc: var JsonNode, checks, defaults): untyped =
  ## checks bracket [ tuple( currentValue[0], defaultValue[1] ) ]
  ## if whatYouWannaReturnIfItwasValid was not there we assume that he wants to return currentValue
  checks.expectKind nnkBracket
  defaults.expectKind {nnkIdent, nnkSym}
  result = newstmtlist()

  for item in checks.children:
    item.expectKind {nnkIdent, nnkAccQuoted}
    
    result.add do: superQuote:
      if `item` != `defaults`.`item`:
        `acc`[`item.getStrName`] = % `item`

macro addIfIsNotDefault*(acc: var seq[DoubleStrTuple], checks, defaults): untyped =
  ## checks bracket [ tuple( currentValue[0], defaultValue[1], whatYouWannaReturnIfItwasValid[2] ) ]
  ## if whatYouWannaReturnIfItwasValid was not there we assume that he wants to return currentValue
  checks.expectKind nnkBracket
  result = newstmtlist()

  for item in checks.children:
    item.expectKind {nnkIdent, nnkAccQuoted}
    
    result.add do: superQuote:
      if `item` != `defaults`.`item`:
        `acc`.add (`item.getStrName`, $ `item`)


template createNadd*(data, checks, default): untyped=
  block:
    var res = data
    res.addIfIsNotDefault(checks, default)
    res

# TODO move it to the tests
when isMainModule:
  proc hey(a: bool, `b` = "hello", c = 2) {.captureDefaults.} =
    var list: seq[DoubleStrTuple]
    list.addIfIsNotDefault [`b`, c], heydefaults

    echo list

  hey(false, "do not show c")
  hey(false, "show c", 3)

  # proc test(a: bool, b: string, c = 2) {.captureDefaults.} =
    # echo "c: ", defaults.c

  # test(false, "das")