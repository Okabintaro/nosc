## Python bindings for nosc
## 
## Build with `nim c --app:lib --mm:arc --opt:size --threads:on --out:py/noscpy.so py/noscpy.nim`
## 
## I would like to have more features in nimpy to make a better binding.
## You could probably also build a wrapper .py around this binding but I think
## it would be less efficient and elegant. Might look at it further.
## 
import nimpy
import nimpy/py_types
import nimpy/py_lib
import pytypes
import nosc
import nosc/hexprint

type NoscMessage = nosc.OscMessage

type OscMessage = ref object of PyNimObjectExperimental
  ## An OSC Message.
  ## 
  ## NOTE: There is no constructor/__init__ for this type.
  ## Use `parse` to create one from a datagram or `message` to create one from scratch.
  ## 
  msg: NoscMessage

proc dgram(self: OscMessage): seq[byte] {.exportpy.} =
  ## Returns the OSC message as a datagram.
  let s: string = self.msg.dgram()
  var bytes = newSeqOfCap[byte](s.len)
  for i in 0..<s.len:
    bytes.add(s[i].byte)
  return bytes

proc str(self: OscMessage): string {.exportpy.} =
  ## Return a string representation of the OSC message.
  $self.msg

proc hexprint(self: OscMessage): string {.exportpy.} =
  ## Return a hex pretty-print of the OSC message, for debugging.
  hexPrint(self.msg.dgram())

proc parse(buffer: string): OscMessage {.exportpy.} =
  ## Parse the OSC message from a datagram.
  let msg = parseMessage(buffer)
  return OscMessage(msg: msg)

proc message(address: string, args: seq[PyObject]): OscMessage {.exportpy.} =
  ## Create an OSC message using the given address and arguments.
  ## Limited to int32, float32 and string for now.
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
      of pbBytes:
        vals.add(%%a.to(string))
      of pbString:
        vals.add(%a.to(string))
      of pbBool:
        vals.add(%a.to(bool))
      else:
        # TODO: Raise Proper ValueError from python?
        raise newException(ValueError, "Unsupported python type: " & $pt)

  let msg = NoscMessage(address: address, args: vals)
  return OscMessage(msg: msg)

proc arg(self: OscMessage, index: int): PPyObject {.exportpy.} =
  ## Get the i-th argument of the OSC message.
  ## Limited to int32, float32 and string for now.
  let val = self.msg.args[index]
  # TODO: Add support for more types
  case val.kind:
    of oscInt:
      return val.intVal.nimValueToPy()
    of oscFloat:
      return val.floatVal.nimValueToPy()
    of oscString:
      return val.strVal.nimValueToPy()
    of oscBlob:
      return val.blobVal.nimValueToPy()
    of oscTrue:
      return true.nimValueToPy()
    of oscFalse:
      return false.nimValueToPy()
    else:
      raise newException(ValueError, "Unsupported OSC type: " & $val.kind)


proc printType(arg: PyObject) {.exportpy.} =
  let pt = baseType(arg.rawPyObj)
  echo "arg: ", pt

