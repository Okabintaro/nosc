# Copied and edited type helpers from nimpy/py_nim_marshalling, since it's not exposed by default
# MIT License, Copyright (c) 2017 Yuriy Glukhov
# See LICENSE.nimpy for license
import nimpy/py_lib as lib
import nimpy/[py_types, py_utils]

type
  PyBaseType* = enum
    pbUnknown
    pbLong
    pbFloat
    pbComplex
    pbCapsule # not used
    pbTuple
    pbList
    pbBytes
    pbUnicode
    pbDict
    pbString
    pbObject
    pbBool


proc baseType*(o: PPyObject): PyBaseType =
  # returns the correct PyBaseType of the given PyObject extracted
  # by manually checking all types
  # If no call to `returnIfSubclass` returns from this proc, the
  # default value of `pbUnknown` will be returned
  template returnIfSubclass(pyt, nimt: untyped): untyped =
    if checkObjSubclass(o, pyt):
      return nimt

  let checkTypes = {
             pyLib.PyFloat_Type : pbFloat,
             pyLib.PyComplex_Type : pbComplex,
             pyLib.PyBool_Type : pbBool,
             pyLib.PyBytes_Type : pbBytes,
             pyLib.PyUnicode_Type : pbString,
             pyLib.PyList_Type : pbList,
             pyLib.PyTuple_Type : pbTuple,
             pyLib.PyDict_Type : pbDict,
  }

  for tup in checkTypes:
    let
      k = tup[0]
      v = tup[1]
    returnIfSubclass(k, v)

  returnIfSubclass(Py_TPFLAGS_INT_SUBCLASS or Py_TPFLAGS_LONG_SUBCLASS, pbLong)
  # if we have not returned until here, `pbUnknown` is returned


proc nimStringAsBytes*(v: string): PPyObject {.inline.} =
  return pyLib.Py_BuildValue("y#", v.cstring, v.len.cint)