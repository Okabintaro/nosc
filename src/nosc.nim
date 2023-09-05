## This module implements parsing of OSC messages.

import std/endians
import std/times

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
    of oscInt: intVal*: int
    of oscFloat: floatVal*: float
    of oscString: strVal*: string
    of oscBlob: blobVal*: string
    of oscTrue: discard
    of oscFalse: discard
    of oscNil: discard
    of oscArray: arrayVal*: seq[OscValue]
    of oscTime: timeVal*: DateTime
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
proc `%`*(v: int): OscValue = OscValue(kind: oscInt, intVal: v)
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


proc parseString(payload: string, val: var string): int =
  ## Parse OSC String, returning the length of the \0 padded string.
  var strLen = 0
  for c in payload:
      if c == '\0':
        break
      strLen += 1
  val = payload[0..<strLen]
  let strPadLen = if strLen %% 4 != 0 :strLen + (4 - strLen %% 4) else: strLen
  return strPadLen

proc parsePayload(payload: string, typeTags: string, i: var int, j: var int, depth: int = 0): seq[OscValue] =
  ## Parse the payload of an OSC message.
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
        let bytes = payload[i..<i+4]
        var tmp: float32 = 0
        bigEndian32(cast[cstring](tmp.addr), cast[cstring](bytes.cstring))
        value = OscValue(kind: oscFloat, floatVal: tmp)
        i += 4
      of 'i':
        let bytes = payload[i..<i+4]
        var tmp: int32 = 0
        bigEndian32(cast[cstring](tmp.addr), cast[cstring](bytes.cstring))
        value = OscValue(kind: oscInt, intVal: tmp)
        i += 4
      of 's':
        var val: string
        i += parseString(payload[i..<payload.len], val)
        value = OscValue(kind: oscString, strVal: val)
      of 'b':
        let bytes = payload[i..<i+4]
        var nBytes: int32 = 0
        bigEndian32(cast[cstring](nBytes.addr), cast[cstring](bytes.cstring))
        i += 4
        let val: string = payload[i..<i+nBytes]
        value = OscValue(kind: oscBlob, blobVal: val)
        let blobValLen = if nBytes %% 4 != 0 :nBytes + (4 - nBytes %% 4) else: nBytes
        i += blobValLen
      of 'T':
        value = OscValue(kind: oscTrue)
      of 'F':
        value = OscValue(kind: oscFalse)
      of 'N':
        value = OscValue(kind: oscNil)
      of '[':
        let arr = parsePayload(payload, typeTags, i, j, depth+1)
        value = OscValue(kind: oscArray, arrayVal: arr)
      of ']':
        if depth == 0:
          raise newException(OscParseError, "Unmatched `]`")
        return params
      of 't':
        # TODO: Port the ntp parsing logic from python
        value = OscValue(kind: oscTime, timeVal: now())
        i += 8
      of 'h':
        let bytes = payload[i..<i+8]
        var val: int64 = 0
        bigEndian64(cast[cstring](val.addr), cast[cstring](bytes.cstring))
        value = OscValue(kind: oscBigInt, bigIntVal: val)
        i += 8
      else:
        # TODO: Add option to surpress this warning or raise error
        echo "Warning: Unknown type tag: ", t
        continue
    params.add(value)

  return params

proc parseMessage*(data: string, ignore_unknown: bool = false): OscMessage {.raises: [OscParseError, Exception].} =
  ## Parse the given data into an OscMessage object.
  ## Raise an OSCParseError if the data is invalid.
  if data[0] != '/':
    raise newException(OscParseError, "Invalid address, no `/` in the beginning")

  # Parse address
  var address: string
  let addrLen = parseString(data, address)
  # Read types
  var typeTags: string
  let typesLen = parseString(data[addrLen..<data.len], typeTags)

  # Parse the payload/values together with the types
  # NOTE: This is kind of ugly passing i and j as var, but it works
  # Need to read some other parsers to see how they do it
  let dataStart = addrLen + typesLen
  var i, j: int = 0
  let params = parsePayload(data[dataStart..<data.len], typeTags, i, j)
  # echo "Here: ", paramStack[^1]
  result = OscMessage(address: address, params: params)