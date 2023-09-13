# Trying to generate python type hints from nim procs
import macros
import strformat
import options

func mapToPyType(nimType: string): string =
  case nimType:
    of "string": result = "str"
    of "int": result = "int"
    else:
      error("Unknown type: " & $nimType)

proc writeProcPyi(prc: NimNode, procName: string): string =
  ## Translate the given proc definition to a python interface definition for type hints.
  # TODO: Use Comment node if possible
  var comment: Option[string] = none(string)
  if prc.body.kind == nnkStmtList and prc.body.len != 0 and prc.body[0].kind == nnkCommentStmt:
    comment = some($prc.body[0])
  else:
    comment = none(string)

  var procIdent = prc.name
  var procName = procName
  if procName.len == 0:
    procName = $procIdent

  # let isMethod = prc.params.len > 1 and $prc.params[1][0] == "self"
  # echo prc.treeRepr(), "\n\n"
  var pyParams = ""

  let formalParams = prc[3]
  expectKind(formalParams, nnkFormalParams)
  let retType = formalParams[0]

  var i = 0
  for param in formalParams[1..<formalParams.len]:
    let name = param[0]
    let typ = param[1]
    if i > 0:
      pyParams.add(", ")
    pyParams.add(fmt"{name}: {($typ).mapToPyType}")

    inc i

  # for param in pyParams:
  #   echo param

  var pyRetType = "None"
  if retType.kind == nnkIdent:
    pyRetType = ($retType).mapToPyType

  result = &"def {procName}({pyParams}): -> {pyRetType}:"
  if comment.isSome:
    result.add("\n  \"\"\"" & $comment.get & "\"\"\"")
  else:
    result.add("...")

  # let identDefs = formalParams[1]
  # expectKind(identDefs, nnkIdentDefs)
  # echo identDefs.treeRepr



macro generatePyi(nameOrProc: untyped, maybeProc: untyped = nil): untyped = 
  var procDef: NimNode
  var procName: string
  if maybeProc.kind == nnkNilLit:
    procDef = nameOrProc
    procName = $procDef.name
  else:
    procDef = maybeProc
    procName = $nameOrProc

  expectKind(procDef, {nnkProcDef, nnkFuncDef, nnkIteratorDef})

  # echo "Generating pyi for ", procDef.name
  let prc = writeProcPyi(procDef, procName)
  echo prc
  result = newEmptyNode()


proc hello(val: string): string {.generatePyi.} =
    ## This is a documentation comment.
    echo "Hello " & val

proc other(val: int) {.generatePyi.} =
    val + 1

