# Python bindings for nosc
# Build with `nim c --app:lib --mm:arc --opt:size --threads:on --out:py/noscpy.so py/noscpy.nim`
import nimpy
import nimpy/py_lib as lib
import nimpy/[py_types, py_utils]

import nosc

# Copied from nimpy, since it's not exposed by default
type
  PyBaseType = enum
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


proc baseType(o: PPyObject): PyBaseType =
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



type PyOscMessage = ref object of PyNimObjectExperimental
  msg: OscMessage

proc dgram(self: PyOscMessage): seq[byte] {.exportpy.} =
  let s: string = self.msg.dgram()
  var bytes = newSeqOfCap[byte](s.len)
  for i in 0..<s.len:
    bytes.add(s[i].byte)
  return bytes

proc arg(self: PyOscMessage, index: int): OscValue {.exportpy.} =
  self.msg.params[index]

proc str(self: PyOscMessage): string {.exportpy.} =
  $self.msg

proc parse(buffer: string): PyOscMessage {.exportpy.} =
  let msg = parseMessage(buffer)
  return PyOscMessage(msg: msg)

proc build(address: string, args: seq[PyObject]): PyOscMessage {.exportpy.} =
  var vals: seq[OscValue] = @[]
  for a in args:
    let pt = baseType(a.rawPyObj)
    case pt:
      of pbLong:
        vals.add(%a.to(int32))
        # TODO: Fallback to int64 if int32 is not enough
      of pbFloat:
        vals.add(%a.to(float32))
        # TODO: Fallback to float64 if float32 is not enough
      of pbString:
        vals.add(%a.to(string))
      else:
        raise newException(ValueError, "Unsupported python type: " & $pt)

  let msg = OscMessage(address: address, params: vals)
  return PyOscMessage(msg: msg)
