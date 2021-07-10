import macros

dumpTree:
  hamid and ali and mahdi and reza

when false:
  Infix:
    Ident "and"
    Infix:
      Ident "and"
      Infix:
        Ident "and"
        Ident "hamid"
        Ident "ali"
      Ident "mahdi"
    Ident "reza"

func flattenDeepInfix*(nestedInfix: NimNode, infixIdent: string): NimNode =
  ## return a statement list of idents
  doAssert nestedInfix.kind == nnkInfix
  result = newStmtList()

  var currentNode = nestedInfix
  while true:
    result.add currentNode[2]

    let body = currentNode[1]
    if body.kind != nnkInfix:
      if body.repr != infixIdent:
        result.insert 0, body
      break

    currentNode = body

static:
  let a = quote:
    hamid and ali and mahdi and reza

  echo a.treeRepr
  echo a.flattenDeepInfix("and").treeRepr