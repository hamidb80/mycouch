import macros, strformat
import macroutils, macroplus

type DoubleStrTuple* = tuple[key: string, val: string]

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

  result = newLetStmt(ident"defaults", newnimNode(nnkTupleConstr))

  for arg in routine[RoutineFormalParams][FormalParamsArguments]:
    if arg[IdentDefDefaultVal].kind != nnkEmpty:
      result[0][IdentDefVal].add newNimNode(nnkExprColonExpr).add(
        arg[IdentDefName],
        arg[IdentDefDefaultVal]
      )

  # echo result.treeRepr
  routine[RoutineBody].insert(0, result)

  return routine

macro addIfIsNotDefault*(acc: var seq[DoubleStrTuple], checks: untyped): untyped =
  ## checks bracket [ tuple( currentValue[0], defaultValue[1], whatYouWannaReturnIfItwasValid[2] ) ]
  ## if whatYouWannaReturnIfItwasValid was not there we assume that he wants to return currentValue
  checks.expectKind nnkBracket
  result = newstmtlist()

  for item in checks.children:
    item.expectKind nnkTupleConstr
    result.add do: superQuote:
      if `item[0]` != `item[1]`:
        `acc`.add (`item[0].strval`, `item[2]`)

# TODO move it to the tests
when isMainModule:
  proc hey(a: bool, b = "hello", c = 2) {.captureDefaults.} =
    var list: seq[DoubleStrTuple]
    addIfIsNotDefault list, [(b, defaults.b, $b), (c, defaults.c, "yay")]

    echo list

  hey(false, "do not show c")
  hey(false, "show c", 3)

  proc test(a: bool, b: string, c = 2) {.captureDefaults.} =
    echo "c: ", defaults.c

  test(false, "das")