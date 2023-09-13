import nimpy/py_lib as lib
import nimpy/[py_types, py_utils]

# Copied from nimpy, since it's not exposed by default
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


proc baseType*(o: PPyObject): PyBaseType =
  # returns the correct PyBaseType of the given PyObject extracted
  # by manually checking all types
  # If no call to `returnIfSubclass` returns from this proc, the
  # default value of `pbUnknown` will be returned
  template returnIfSubclass(pyt, nimt: untyped): untyped =
    if checkObjSubclass(o, pyt):
      return nimt

  # check int types first for backward compatibility with Python2
  returnIfSubclass(Py_TPFLAGS_INT_SUBCLASS or Py_TPFLAGS_LONG_SUBCLASS, pbLong)

  let checkTypes = { pyLib.PyFloat_Type : pbFloat,
             pyLib.PyComplex_Type : pbComplex,
             pyLib.PyBytes_Type : pbString,
             pyLib.PyUnicode_Type : pbString,
             pyLib.PyList_Type : pbList,
             pyLib.PyTuple_Type : pbTuple,
             pyLib.PyDict_Type : pbDict }

  for tup in checkTypes:
    let
      k = tup[0]
      v = tup[1]
    returnIfSubclass(k, v)
  # if we have not returned until here, `pbUnknown` is returned
