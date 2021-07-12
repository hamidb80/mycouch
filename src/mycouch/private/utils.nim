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

macro addIfIsNotDefault*(acc: var JsonNode, checks: untyped): untyped =
  ## checks bracket [ tuple( currentValue[0], defaultValue[1] ) ]
  ## if whatYouWannaReturnIfItwasValid was not there we assume that he wants to return currentValue
  checks.expectKind nnkBracket
  result = newstmtlist()

  for item in checks.children:
    item.expectKind nnkTupleConstr
    
    result.add do: superQuote:
      if `item[0]` != `item[1]`:
        `acc`[`item[0].strval`] = % `item[0]`

macro addIfIsNotDefault*(acc: var seq[DoubleStrTuple], checks: untyped): untyped =
  ## checks bracket [ tuple( currentValue[0], defaultValue[1], whatYouWannaReturnIfItwasValid[2] ) ]
  ## if whatYouWannaReturnIfItwasValid was not there we assume that he wants to return currentValue
  checks.expectKind nnkBracket
  result = newstmtlist()

  for item in checks.children:
    item.expectKind nnkTupleConstr
    
    result.add do: superQuote:
      if `item[0]` != `item[1]`:
        `acc`.add (`item[0].strval`, $ `item[2]`)

# TODO move it to the tests
when isMainModule:
  proc hey(a: bool, b = "hello", c = 2) {.captureDefaults.} =
    var list: seq[DoubleStrTuple]
    addIfIsNotDefault list, [(b, heydefaults.b, $b), (c, heydefaults.c, "yay")]

    echo list

  hey(false, "do not show c")
  hey(false, "show c", 3)

  # proc test(a: bool, b: string, c = 2) {.captureDefaults.} =
    # echo "c: ", defaults.c

  # test(false, "das")