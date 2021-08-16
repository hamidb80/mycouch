import macros, json
import macroutils, macroplus, strutils
import coverage

type DoubleStrTuple* = tuple[key: string, val: string]

macro captureDefaults*(routine): untyped =
  when defined(docs):
    routine[^1] = routine[^1].extractDocCommentsAndRunnables
    return routine

  ## this macro captures all default valued arguments and save them in a let defaults: tulple[arg1: defaultVal, arg2: ...,]
  ## in the head of the routine

  routine.expectKind RoutineNodes

  # let defaults {.global.} = (a:2, b:3)
  #
  # LetSection:
  #   IdentDef:
  #    PragmaExpr
  #      Ident "defaults"
  #      Pragma
  #        Ident "global"
  #     Empty
  #     TupleConstr:
  #       ExprColonExpr:
  #         Ident "a"
  #         IntLit 2
  #       ExprColonExpr:
  #         Ident "b"
  #         IntLit 3

  var defs = quote: 
    let defaults {.used, inject, global.} = nil # use global pragma to initiate it at soon as program started

  defs[0][IdentDefDefaultVal] = newNimNode(nnkTupleConstr)

  for arg in routine[RoutineFormalParams][FormalParamsArguments]:
    if arg[IdentDefDefaultVal].kind != nnkEmpty:
      for ident in arg[IdentDefNames]:
        defs[0][IdentDefDefaultVal].add newNimNode(nnkExprColonExpr).add(
          ident, 
          arg[IdentDefDefaultVal]
        )
  
  routine[RoutineBody].insert 0, defs
  return routine

macro addTestCov*(body): untyped=
  # TODO: add cov pragma only if custom test flags are provided
  when not defined(test): 
    return body

  body.expectKind nnkStmtList

  for prc in body:
    if prc.kind in {nnkProcDef, nnkFuncDef}:
      if prc.pragmas.kind == nnkEmpty:
        prc.pragmas = newNimNode(nnkPragma)

      prc.pragmas.insert 0, bindSym("cov")

  body

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
    list.addIfIsNotDefault [`b`, c], defaults

    echo list

  hey(false, "do not show c")
  hey(false, "show c", 3)

  # proc test(a: bool, b: string, c = 2) {.captureDefaults.} =
    # echo "c: ", defaults.c

  # test(false, "das")