## This module implements parsing of OSC messages.

import std/endians
import std/parseutils

type
  OscParseError* = object of CatchableError

type
  OscType* = enum
    oscFloat,
    oscInt,
    oscString,
    oscBlob,
    oscTrue,
    oscFalse,
    oscNil,
    oscArray,
    oscTime,
    oscBigInt,
  OscValue* = object
    case kind*: OscType
    of oscInt: intVal*: int32
    of oscFloat: floatVal*: float32
    of oscString: strVal*: string
    of oscBlob: blobVal*: string
    of oscTrue: discard
    of oscFalse: discard
    of oscNil: discard
    of oscArray: arrayVal*: seq[OscValue]
    of oscTime: timeVal*: int
    of oscBigInt: bigIntVal*: int64
  OscMessage* = object
    address*: string
    params*: seq[OscValue]

# Convert nim types to OSCValue, similar to JsonNode
proc `%`*(b: bool): OscValue =
  if b:
    return OscValue(kind: oscTrue)
  else:
    return OscValue(kind: oscFalse)
proc `%`*(v: int): OscValue = OscValue(kind: oscInt, intVal: v.int32)
proc `%`*(v: int32): OscValue = OscValue(kind: oscInt, intVal: v)
proc `%`*(v: int64): OscValue = OscValue(kind: oscBigInt, bigIntVal: v)
proc `%`*(v: float32): OscValue = OscValue(kind: oscFloat, floatVal: v) 
proc `%`*(v: float): OscValue = OscValue(kind: oscFloat, floatVal: v) 
proc `%`*(v: string): OscValue = OscValue(kind: oscString, strVal: v)
proc `%`*[T](elements: openArray[T]): OscValue =
  var arr: seq[OscValue]
  for elem in elements: arr.add(%elem)
  return OscValue(kind: oscArray, arrayVal: arr)
proc `%`*(v: OscValue): OscValue = v

# Compare OSCValues
proc `==`*(a, b: OscValue): bool =
  if a.kind != b.kind:
    return false
  case a.kind:
    of oscInt:
      return a.intVal == b.intVal
    of oscFloat:
      return a.floatVal == b.floatVal
    of oscString:
      return a.strVal == b.strVal
    of oscBlob:
      return a.blobVal == b.blobVal
    of oscTrue, oscFalse, oscNil:
      return true
    of oscArray:
      let arr = a.arrayVal
      if arr.len != arr.len:
        return false
      for i in 0..<arr.len:
        if a.arrayVal[i] != b.arrayVal[i]:
          return false
      return true
    of oscTime:
      return a.timeVal == b.timeVal
    of oscBigInt:
      return a.bigIntVal == b.bigIntVal


func pad4(length: int): int {.inline} =
  ## Pad the given length to the next multiple of 4.
  if length %% 4 != 0:
    return length + (4 - length %% 4)
  else:
    return length

proc readString(payload: openArray[char], i: var int): string =
  ## Parse OSC String, returning the length of the \0 padded string.
  # TODO: See if we can parse without allocating the string in parseUntil
  # https://nim-lang.org/docs/manual_experimental.html#view-types
  let len = payload.parseUntil(result, '\0')
  i += pad4(len)

# TODO: Type constraint T to 32bit types?
proc readBe32[T](payload: openArray[char], i: var int): T {.inline} =
  bigEndian32(cast[cstring](result.addr), cast[cstring](payload))
  i += 4

# TODO: Type constraint T to 64bit types
proc readBe64[T](payload: openArray[char], i: var int): T {.inline} =
  bigEndian64(cast[cstring](result.addr), cast[cstring](payload))
  i += 8

proc readArguments(payload: string, typeTags: string, i: var int, j: var int, depth: int = 0): seq[OscValue] =
  ## Parse the payload of an OSC message.
  ## Here payload and typeTags are "streams" with i, j as the current position.
  ## Raise an OSCParseError if the data is invalid.
  var params: seq[OscValue] = @[]
  while j < typeTags.len:
    var value: OscValue
    let t = typeTags[j]
    inc j
    case t:
      of ',':
        continue
      of 'f':
        value = OscValue(kind: oscFloat, floatVal: readBe32[float32](payload[i..<i+4], i))
      of 'i':
        value = OscValue(kind: oscInt, intVal: readBe32[int32](payload[i..<i+4], i))
      of 's':
        value = OscValue(kind: oscString, strVal: readString(payload[i..<payload.len], i))
      of 'b':
        var length = readBe32[int32](payload[i..<i+4], i)
        let val: string = payload[i..<i+length]
        value = OscValue(kind: oscBlob, blobVal: val)
        # TODO: Make template/proc for this
        i += pad4(length)
      of 'T':
        value = OscValue(kind: oscTrue)
      of 'F':
        value = OscValue(kind: oscFalse)
      of 'N':
        value = OscValue(kind: oscNil)
      of '[':
        let arr = readArguments(payload, typeTags, i, j, depth+1)
        value = OscValue(kind: oscArray, arrayVal: arr)
      of ']':
        if depth == 0:
          raise newException(OscParseError, "Unmatched `]`")
        return params
      of 't':
        # TODO: Port the ntp parsing logic from python
        value = OscValue(kind: oscTime, timeVal: 0)
        i += 8
      of 'h':
        value = OscValue(kind: oscBigInt, bigIntVal: readBe64[int64](payload[i..<i+8], i))
      else:
        # TODO: Add option to surpress this warning or raise error
        echo "Warning: Unknown type tag: ", t
        continue
    params.add(value)

  return params

proc parseMessage*(data: string, ignore_unknown: bool = false): OscMessage {.raises: [OscParseError].} =
  ## Parse the given data into an OscMessage object.
  ## Raise an OSCParseError if the data is invalid.
  if data[0] != '/':
    raise newException(OscParseError, "Invalid address, no `/` in the beginning")

  # Read address and type tags
  var k: int = 0
  var address = readString(data, k)
  var typeTags = readString(data[k..<data.len], k)

  # Parse the payload/values together with the types
  # NOTE: This is kind of ugly passing i and j as var, but it works
  # Need to read some other parsers to see how they do it
  var i, j: int = 0
  let params = readArguments(data[k..<data.len], typeTags, i, j)
  # echo "Here: ", paramStack[^1]
  result = OscMessage(address: address, params: params)