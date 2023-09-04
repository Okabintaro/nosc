## This module implements parsing of OSC messages.

import std/strutils
import std/endians

type
  OscParseError* = object of CatchableError

type
  OscType* = enum
    oscFloat,
    oscInt,
    oscString,
    oscBlob
  OscValue* = object
    case kind*: OscType
    of oscInt: intVal*: int
    of oscFloat: floatVal*: float
    of oscString: strVal*: string
    of oscBlob: blobVal*: string
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
    else:
      raise newException(OscParseError, "Unsupported type: \"" & name & "\"")


proc parseMessage*(data: string): OscMessage {.raises: [OscParseError].} =
  ## Parse the given data into an OscMessage object.
  ## Raise an OSCParseError if the data is invalid.
  if data[0] != '/':
    raise newException(OscParseError, "Invalid address, no `/` in the beginning")

  # Parse address
  let address: string = block:
    var addrStrLen = 1
    for c in data[1..<data.len]:
      if c == '\0':
        break
      addrStrLen += 1
    data[0..<addrStrLen]

  # Try to parse types if any
  # TODO: Should start later to look for the comma
  let comma = data.find(",")
  if comma == -1:
    return OscMessage(address: address)

  # Parse types after comma
  var expectedTypes: seq[OscType]
  var typesEnd = 0
  for i in countup(comma+1, data.len-1):
    let c = data[i]
    if c == '\0':
      typesEnd = i
      break
    expectedTypes.add(c.parseType)

  # TODO: Introduce macro/func to calculate the padding
  var typesLen = expectedTypes.len + 1
  if typesLen %% 4 != 0:
    typesLen = typesLen + (4 - typesLen %% 4)
  assert typesLen %% 4 == 0

  # Parse the payload/values
  let dataStart = comma + typesLen
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
        var strLen = 0
        for c in payload[i..<payload.len]:
          if c == '\0':
            break
          strLen += 1
        let val: string = payload[i..<i+strLen]
        values.add(OscValue(kind: oscString, strVal: val))
        let strPadLen = if strLen %% 4 != 0 :strLen + (4 - strLen %% 4) else: strLen
        i += strPadLen
      of oscBlob:
        let bytes = payload[i..<i+4]
        var nBytes: int32 = 0
        bigEndian32(cast[cstring](nBytes.addr), cast[cstring](bytes.cstring))
        i += 4
        let val: string = payload[i..<i+nBytes]
        values.add(OscValue(kind: oscBlob, blobVal: val))
        let blobValLen = if nBytes %% 4 != 0 :nBytes + (4 - nBytes %% 4) else: nBytes
        i += blobValLen

  result = OscMessage(address: address, params: values)