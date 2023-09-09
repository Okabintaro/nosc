## This module implements parsing of OSC messages.

import std/endians
import std/parseutils
import std/times
import std/colors


type
  OscParseError* = object of CatchableError


proc fractionToNano*(fraction: uint32): uint32 =
  let frac = (fraction.float64 * 1_000_000_000) / (1 shl 32).float64
  return frac.uint32

proc nanoToFraction*(nanoseconds: uint32): uint32 =
  return ((nanoseconds.float64 / 1_000_000_000'f64) * (1 shl 32).float64).uint32

type 
  OscTime* = object
    seconds: uint32
    frac: uint32

const OscTimeImmediate* = OscTime(seconds: 0, frac: 1)

proc isImmediate*(time: OscTime): bool {.inline.} =
  return time == OscTimeImmediate

# let NTP_EPOCH = dateTime(1900, mJan, 1, zone=utc()).toTime()
# NTP_EPOCH: Time(seconds: -2208988800, nanosecond: 0)
const NTP_EPOCH = initTime(-2208988800, 0)

proc toTime*(time: OscTime): Time =
  ## Convert the given OSC/NTP timestamp to a Time object.
  ## 
  ## This conversation is lossy. Doing a round-trip will have a deviation of 1 nanosecond.
  ## See test/times.nim for the test that shows that.
  ## 
  ## NOTE: This does not handle the special case of an immediate time.
  ## You have to check using isImmediate yourself.
  let unixSeconds = time.seconds.int64 + NTP_EPOCH.toUnix()
  let nano = fractionToNano(time.frac)
  return initTime(unixSeconds,nano)

proc toOscTime*(time: Time): OscTime =
  ## Convert the given time to an OSC/NTP Timestamp.
  result.seconds = (time.toUnix() - NTP_EPOCH.toUnix()).uint32
  result.frac = nanoToFraction(time.nanosecond.uint32)

type OscColor* {.packed.} = object
  r*: uint8
  g*: uint8
  b*: uint8
  a*: uint8

proc toColor*(c: OscColor): Color =
  Color(c.r shl 16 or c.g shl 8 or c.b)

proc toOscColor*(c: Color, alpha: uint8): OscColor =
  let rgb = extractRGB(c)
  OscColor(r: rgb.r.uint8, g: rgb.g.uint8, b: rgb.b.uint8, a: alpha)

type OscMidi* {.packed.} = object
  ## MIDI message. Bytes from MSB to LSB are: port id, status byte, data1, data2
  portId*: uint8
  status*: uint8
  data1*: uint8
  data2*: uint8

type
  OscType* = enum
    oscFloat = "f",
    oscInt = "i",
    oscString = "s",
    oscBlob = "b",
    oscTrue = "T",
    oscFalse = "F",
    oscNil = "N",
    oscInf = "I",
    oscArray = "[",
    oscTime = "t",
    oscBigInt = "h",
    oscDouble = "d",
    oscChar = "c",
    oscColor = "r",
    oscMidi = "m",
  OscValue* = object
    case kind*: OscType
    of oscInt: intVal*: int32
    of oscFloat: floatVal*: float32
    of oscString: strVal*: string
    of oscBlob: blobVal*: string
    of oscTrue: discard
    of oscFalse: discard
    of oscNil: discard
    of oscInf: discard
    of oscArray: arrayVal*: seq[OscValue]
    of oscTime: timeVal*: OscTime
    of oscBigInt: bigIntVal*: int64
    of oscDouble: doubleVal*: float64
    of oscChar: charVal*: char
    of oscColor: colorVal*: OscColor
    of oscMidi: midiVal*: OscMidi
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
proc `%`*(v: string): OscValue = OscValue(kind: oscString, strVal: v)
proc `%`*(v: OscTime): OscValue = OscValue(kind: oscTime, timeVal: v)
proc `%`*(v: Time): OscValue = OscValue(kind: oscTime, timeVal: v.toOscTime())
proc `%`*(v: char): OscValue = OscValue(kind: oscChar, charVal: v)
proc `%`*(v: OscColor): OscValue = OscValue(kind: oscColor, colorVal: v)
proc `%`*(v: OscMidi): OscValue = OscValue(kind: oscMidi, midiVal: v)
  


proc toOscDouble*(v: float64): OscValue =
  ## I decided to not add a `%` overload for float64, since it's not a standard OSC type and you want float32 most of the time.
  OscValue(kind: oscDouble, doubleVal: v)

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
    of oscDouble:
      return a.doubleVal == b.doubleVal
    of oscString:
      return a.strVal == b.strVal
    of oscBlob:
      return a.blobVal == b.blobVal
    of oscTrue, oscFalse, oscNil, oscInf:
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
    of oscChar:
      return a.charVal == b.charVal
    of oscColor:
      return a.colorVal == b.colorVal
    of oscMidi:
      return a.midiVal == b.midiVal


# TODO: There should be way to do %inf -> oscInf and %nil -> oscNil in nim
# Gotta learn macros or templates for that
const OscInf* = OscValue(kind: oscInf)
const OscNil* = OscValue(kind: oscNil)

func pad4(length: int): int {.inline} =
  ## Return the number of bytes needed to pad the given length to the next multiple of 4.
  if length %% 4 != 0:
    return (4 - length %% 4)
  else:
    return length

func padded4(length: int): int {.inline} =
  ## Pad the given length to the next multiple of 4.
  if length %% 4 != 0:
    return length + (4 - length %% 4)
  else:
    return length

type Bit32Type = int32 | uint32 | float32
type Bit64Type = int64 | uint64 | float64

proc readBe32[T: Bit32Type](payload: openArray[char], i: var int): T {.inline} =
  bigEndian32(cast[cstring](result.addr), cast[cstring](payload))
  i += 4

proc readBe64[T: Bit64Type](payload: openArray[char], i: var int): T {.inline} =
  bigEndian64(cast[cstring](result.addr), cast[cstring](payload))
  i += 8

proc readString(payload: openArray[char], i: var int): string =
  ## Parse OSC String, returning the length of the \0 padded string.
  # TODO: See if we can parse without allocating the string in parseUntil
  # https://nim-lang.org/docs/manual_experimental.html#view-types
  let len = payload.parseUntil(result, '\0')
  i += padded4(len + 1) # len + 1 for the \0


# TODO I wonder if you could use memcpy or a faster way to write the bytes
# One probably shouldn't usse strings for this?
proc writeBytes(buffer: var string, bytes: openArray[byte]): int {.inline} =
  for b in bytes:
    buffer.add(b.char)
  return bytes.len

proc writeBe32[T: Bit32Type](buffer: var string, val: T): int {.inline} =
  var bytes: array[4, byte]
  bigEndian32(bytes.addr, val.addr)
  return writeBytes(buffer, bytes)

proc writeBe64[T: Bit64Type](buffer: var string, val: T): int {.inline} =
  var bytes: array[8, byte]
  bigEndian64(bytes.addr, val.addr)
  return writeBytes(buffer, bytes)

proc writeString*(buffer: var string, val: string): int =
  buffer.add(val)
  let rem = 4 - (val.len %% 4)
  for i in 0..<rem: buffer.add('\0')
  return val.len + rem

proc readOscTime(payload: openArray[char], i: var int): OscTime =
  ## Read an OscTime from the given payload.
  result.seconds = readBe32[uint32](payload[i..<i+4], i)
  result.frac = readBe32[uint32](payload[i..<i+4], i)


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
        i += padded4(length)
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
        value = OscValue(kind: oscTime, timeVal: readOscTime(payload, i))
      of 'h':
        value = OscValue(kind: oscBigInt, bigIntVal: readBe64[int64](payload[i..<i+8], i))
      of 'd':
        value = OscValue(kind: oscDouble, doubleVal: readBe64[float64](payload[i..<i+8], i))
      of 'I':
        value = OscValue(kind: oscInf)
      of 'c':
        let c = readBe32[uint32](payload[i..<i+4], i)
        value = OscValue(kind: oscChar, charVal: c.char)
      of 'r':
        var color: OscColor
        copyMem(color.addr, payload[i].addr, 4)
        value = OscValue(kind: oscColor, colorVal: color)
      of 'm':
        var midiMsg: OscMidi
        copyMem(midiMsg.addr, payload[i].addr, 4)
        value = OscValue(kind: oscMidi, midiVal: midiMsg)
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
  result.address = readString(data, k)
  if k >= data.len:
    return
  var typeTags = readString(data[k..<data.len], k)

  # Parse the payload/values together with the types
  # NOTE: This is kind of ugly passing i and j as var, but it works
  # Need to read some other parsers to see how they do it
  var i, j: int = 0
  let params = readArguments(data[k..<data.len], typeTags, i, j)
  result.params = params

proc writeTags*(buffer: var string, args: seq[OscValue]): int =
  var i: int = 0
  for arg in args:
    let kind = arg.kind
    case kind:
      of oscArray:
        buffer.add("["); inc i
        i += buffer.writeTags(arg.arrayVal)
        buffer.add("]"); inc i
      else:
        let typeChar = $arg.kind
        assert typeChar.len == 1
        buffer.add($arg.kind); inc i

  return i

proc writeArguments*(buffer: var string, args: seq[OscValue], pad: bool = true): int =
  var i: int = 0
  for arg in args:
    let kind = arg.kind
    case kind:
      of oscFloat:
        i += writeBe32[float32](buffer, arg.floatVal)
      of oscInt:
        i += writeBe32[int32](buffer, arg.intVal)
      of oscString:
        i += writeString(buffer, arg.strVal)
      of oscBlob:
        i += writeBe32[int32](buffer, arg.blobVal.len.int32)
        i += writeString(buffer, arg.blobVal)
      of oscTrue, oscFalse, oscNil, oscInf:
        discard
      of oscArray:
        i += buffer.writeArguments(arg.arrayVal, pad=false)
      of oscTime:
        i += buffer.writeBe32(arg.timeVal.seconds)
        i += buffer.writeBe32(arg.timeVal.frac)
      of oscBigInt:
        i += buffer.writeBe64(arg.bigIntVal)
      of oscDouble:
        i += buffer.writeBe64(arg.doubleVal)
      of oscColor:
        i += buffer.writeBytes(cast[array[4, byte]](arg.colorVal))
      of oscMidi:
        i += buffer.writeBytes(cast[array[4, byte]](arg.midiVal))
      of oscChar:
        i += buffer.writeBe32(arg.charVal.int32)

  return i

var typeTagsStr: string = newStringOfCap(512)

proc writeMessage*(buffer: var string, msg: OscMessage): int =
  ## Write the given OscMessage to a string.
  ## This is the inverse of parseMessage.
  var i = 0
  
  i += buffer.writeString(msg.address)
  # NOTE/TODO: I wonder if we could/should allocate typeTagsStr on the stack
  typeTagsStr.setLen(0)
  discard typeTagsStr.writeTags(msg.params)
  i += buffer.writeString("," & typeTagsStr)
  i += buffer.writeArguments(msg.params)

  return i

proc dgram*(msg: OscMessage): string =
  ## Serialize the given OscMessage to a new string and return it.
  var dgram: string = newStringOfCap(512)
  discard dgram.writeMessage(msg)
  return dgram
