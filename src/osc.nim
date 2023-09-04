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


proc parseType(name: char): OscType =
  case name:
    of 'f':
      result = oscFloat
    of 'i':
      result = oscInt
    of 's':
      result = oscString
    of 'b':
      result = oscBlob
    of 'T':
      result = oscTrue
    of 'F':
      result = oscFalse
    of 'N':
      result = oscNil
    of '[':
      result = oscArray
    of 't':
      result = oscTime
    of 'h':
      result = oscBigInt
    else:
      raise newException(OscParseError, "Unsupported type: \"" & name & "\"")

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

proc parseMessage*(data: string): OscMessage {.raises: [OscParseError].} =
  ## Parse the given data into an OscMessage object.
  ## Raise an OSCParseError if the data is invalid.
  if data[0] != '/':
    raise newException(OscParseError, "Invalid address, no `/` in the beginning")

  # Parse address
  var address: string
  let addrLen = parseString(data, address)

  # Parse type tags after optional comma
  # Not sure if this is correct, not requiring the comma, but python-osc does it
  var typeTags: string
  let typesLen = parseString(data[addrLen..<data.len], typeTags)
  assert typesLen %% 4 == 0
  var expectedTypes: seq[OscType]
  for c in typeTags:
    if c == ',':
      continue
    if c == ']':
      continue
    expectedTypes.add(c.parseType)

  if expectedTypes.len == 0:
    return OscMessage(address: address)

  # Parse the payload/values
  let dataStart = addrLen + typesLen
  var values: seq[OscValue]
  var payload = data[dataStart..<data.len]
  var i: int = 0
  for t in expectedTypes:
    case t:
      of oscFloat:
        let bytes = payload[i..<i+4]
        var tmp: float32 = 0
        bigEndian32(cast[cstring](tmp.addr), cast[cstring](bytes.cstring))
        values.add(OscValue(kind: oscFloat, floatVal: tmp))
        i += 4
      of oscInt:
        let bytes = payload[i..<i+4]
        var tmp: int32 = 0
        bigEndian32(cast[cstring](tmp.addr), cast[cstring](bytes.cstring))
        values.add(OscValue(kind: oscInt, intVal: tmp))
        i += 4
      of oscString:
        var val: string
        i += parseString(payload[i..<payload.len], val)
        values.add(OscValue(kind: oscString, strVal: val))
      of oscBlob:
        let bytes = payload[i..<i+4]
        var nBytes: int32 = 0
        bigEndian32(cast[cstring](nBytes.addr), cast[cstring](bytes.cstring))
        i += 4
        let val: string = payload[i..<i+nBytes]
        values.add(OscValue(kind: oscBlob, blobVal: val))
        let blobValLen = if nBytes %% 4 != 0 :nBytes + (4 - nBytes %% 4) else: nBytes
        i += blobValLen
      of oscTrue:
        values.add(OscValue(kind: oscTrue))
      of oscFalse:
        values.add(OscValue(kind: oscFalse))
      of oscNil:
        values.add(OscValue(kind: oscNil))
      of oscArray:
        # TODO: Investigate and port
        values.add(OscValue(kind: oscArray, arrayVal: @[]))
        discard
      of oscTime:
        # TODO: Port the ntp parsing logic from python
        values.add(OscValue(kind: oscTime, timeVal: now()))
        i += 8
      of oscBigInt:
        let bytes = payload[i..<i+8]
        var val: int64 = 0
        bigEndian64(cast[cstring](val.addr), cast[cstring](bytes.cstring))
        values.add(OscValue(kind: oscBigInt, bigIntVal: val))
        i += 8


  result = OscMessage(address: address, params: values)