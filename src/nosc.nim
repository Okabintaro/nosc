## This module implements parsing of OSC messages.
import std/parseutils
import std/colors
import nosc/stream
# On windows and nimscript std/times gives an error:
# nim-2.0.0\lib\windows\winlean.nim(844, 20) Error: VM does not support 'cast' from tyPointer to tyProc
when not (defined(windows) and defined(nimscript)):
  import std/times

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

# Converstion between OSC/NTP and Time
when not (defined(windows) and defined(nimscript)):
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

  proc `%`*(v: Time): OscValue = OscValue(kind: oscTime, timeVal: v.toOscTime())


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

func padded4(length: int): int {.inline} =
  ## Pad the given length to the next multiple of 4.
  if length %% 4 != 0:
    return length + (4 - length %% 4)
  else:
    return length


proc add(buffer: var string, val: OscColor) {.inline.} =
  proc fallback(buffer: var string, val: OscColor) {.inline.} =
    buffer.add(val.r)
    buffer.add(val.g)
    buffer.add(val.b)
    buffer.add(val.a)
  when defined(nimscript) or defined(js):
    fallback(buffer, val)
  else:
    when nimvm:
      fallback(buffer, val)
    else:
      buffer.addUint32(cast[uint32](val))

proc add(buffer: var string, val: OscMidi) {.inline.} =
  proc fallback(buffer: var string, val: OscMidi) {.inline.} =
    buffer.add(val.portId)
    buffer.add(val.status)
    buffer.add(val.data1)
    buffer.add(val.data2)
  when defined(nimscript) or defined(js):
    fallback(buffer, val)
  else:
    when nimvm:
      fallback(buffer, val)
    else:
      buffer.addUint32(cast[uint32](val))


proc addPaddedStr*(buffer: var string, val: string) {.inline.} =
  buffer.add(val)
  let rem = 4 - (val.len %% 4)
  for i in 0..<rem: buffer.add('\0')


proc readPaddedStr(payload: string, i: var int): string =
  ## Parse OSC String, returning the length of the \0 padded string.
  # TODO: See if we can parse without allocating the string in parseUntil
  # https://nim-lang.org/docs/manual_experimental.html#view-types
  let len = payload[i..<payload.high].parseUntil(result, '\0')
  i += padded4(len + 1) # len + 1 for the \0


proc readOscTime(payload: string, i: var int): OscTime =
  result.seconds = readBe32[uint32](payload, i)
  result.frac = readBe32[uint32](payload, i)


proc readOscColor(payload: string, i: var int): OscColor =
  proc readOscColorSlow(payload: string, i: var int): OscColor =
    result.r = payload[i].byte; inc i
    result.g = payload[i].byte; inc i
    result.b = payload[i].byte; inc i
    result.a = payload[i].byte; inc i
  when defined(nimscript) or defined(js):
    result = readOscColorSlow(payload, i)
  else:
    when nimvm:
      result = readOscColorSlow(payload, i)
    else:
      copyMem(result.addr, payload[i].addr, 4); i += 4


proc readOscMidi(payload: string, i: var int): OscMidi =
  proc readOscMidiSlow(payload: string, i: var int): OscMidi =
    result.portId = payload[i].byte; inc i
    result.status = payload[i].byte; inc i
    result.data1 = payload[i].byte; inc i
    result.data2 = payload[i].byte; inc i

  when defined(nimscript) or defined(js):
    result = readOscMidiSlow(payload, i)
  else:
    when nimvm:
      result = readOscMidiSlow(payload, i)
    else:
      copyMem(result.addr, payload[i].addr, 4); i += 4


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
        value = OscValue(kind: oscFloat, floatVal: readBe32[float32](payload, i))
      of 'i':
        value = OscValue(kind: oscInt, intVal: readBe32[int32](payload, i))
      of 's':
        value = OscValue(kind: oscString, strVal: readPaddedStr(payload, i))
      of 'b':
        var length = readBe32[int32](payload, i)
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
        value = OscValue(kind: oscBigInt, bigIntVal: readBe64[int64](payload, i))
      of 'd':
        value = OscValue(kind: oscDouble, doubleVal: readBe64[float64](payload, i))
      of 'I':
        value = OscValue(kind: oscInf)
      of 'c':
        let c = readBe32[uint32](payload, i)
        value = OscValue(kind: oscChar, charVal: c.char)
      of 'r':
        value = OscValue(kind: oscColor, colorVal: readOscColor(payload, i))
      of 'm':
        value = OscValue(kind: oscMidi, midiVal: readOscMidi(payload, i))
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
  result.address = readPaddedStr(data, k)
  if k >= data.len:
    return

  # TODO: Maybe this copy can be avoiced too actually
  var typeTags = readPaddedStr(data, k)

  # Parse the payload/values together with the types
  # NOTE: This is kind of ugly passing i and j as var, but it works
  # Need to read some other parsers to see how they do it
  var j: int = 0
  let params = readArguments(data, typeTags, k, j)
  result.params = params


proc addTags*(buffer: var string, args: seq[OscValue]) =
  for arg in args:
    let kind = arg.kind
    case kind:
      of oscArray:
        buffer.add("[")
        buffer.addTags(arg.arrayVal)
        buffer.add("]")
      else:
        let typeChar = $arg.kind
        assert typeChar.len == 1
        buffer.add($arg.kind)


proc addPaddedTags*(buffer: var string, args: seq[OscValue]) =
  let before = buffer.len
  buffer.add(",")
  buffer.addTags(args)
  let len = buffer.len - before

  # Always pad to 4 bytes with '\0'
  let rem = 4 - (len %% 4)
  for i in 0..<rem: buffer.add('\0')

proc writeArguments*(buffer: var string, args: seq[OscValue], pad: bool = true) =
  for arg in args:
    let kind = arg.kind
    case kind:
      of oscFloat:
        addBe32[float32](buffer, arg.floatVal)
      of oscInt:
        addBe32[int32](buffer, arg.intVal)
      of oscString:
        addPaddedStr(buffer, arg.strVal)
      of oscBlob:
        addBe32[int32](buffer, arg.blobVal.len.int32)
        addPaddedStr(buffer, arg.blobVal)
      of oscTrue, oscFalse, oscNil, oscInf:
        discard
      of oscArray:
        buffer.writeArguments(arg.arrayVal, pad=false)
      of oscTime:
        buffer.addBe32(arg.timeVal.seconds)
        buffer.addBe32(arg.timeVal.frac)
      of oscBigInt:
        buffer.addBe64(arg.bigIntVal)
      of oscDouble:
        buffer.addBe64(arg.doubleVal)
      of oscColor:
        buffer.add(arg.colorVal)
      of oscMidi:
        buffer.add(arg.midiVal)
      of oscChar:
        buffer.addBe32(arg.charVal.int32)

proc writeMessage*(buffer: var string, msg: OscMessage): int =
  ## Write the given OscMessage to a string.
  ## This is the inverse of parseMessage.
  
  buffer.addPaddedStr(msg.address)
  # NOTE/TODO: I wonder if we could/should allocate typeTagsStr on the stack
  buffer.addPaddedTags(msg.params)
  buffer.writeArguments(msg.params)

  return buffer.len

proc dgram*(msg: OscMessage): string =
  ## Serialize the given OscMessage to a new string and return it.
  var dgram: string = newStringOfCap(512)
  discard dgram.writeMessage(msg)
  return dgram
