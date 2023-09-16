## This module implements parsing and serializing of OSC messages.
import std/parseutils
import std/colors
import std/strutils
import nosc/stream
import nosc/errors

export OscParseError

# On windows and nimscript std/times gives an error:
# nim-2.0.0\lib\windows\winlean.nim(844, 20) Error: VM does not support 'cast' from tyPointer to tyProc
when not (defined(windows) and defined(nimscript)):
  import std/times

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

proc addTime(buffer: var string, time: OscTime) {.inline.} =
  buffer.addBe32(time.seconds)
  buffer.addBe32(time.frac)

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
    of oscBlob: blobVal*: seq[byte]
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
    args*: seq[OscValue]

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
proc `%`*(v: seq[byte]): OscValue = OscValue(kind: oscBlob, blobVal: v)
proc `%%`*(v: string): OscValue = OscValue(kind: oscBlob, blobVal: @(v.toOpenArrayByte(0, v.high)))
proc `%`*(v: OscTime): OscValue = OscValue(kind: oscTime, timeVal: v)
proc `%`*(v: char): OscValue = OscValue(kind: oscChar, charVal: v)
proc `%`*(v: OscColor): OscValue = OscValue(kind: oscColor, colorVal: v)
proc `%`*(v: OscMidi): OscValue = OscValue(kind: oscMidi, midiVal: v)
proc `%%`*(v: float64): OscValue = OscValue(kind: oscDouble, doubleVal: v)
  


proc toOscDouble*(v: float64): OscValue =
  ## I decided to not add a `%` overload for float64, since it's not a standard OSC type and you want float32 most of the time.
  OscValue(kind: oscDouble, doubleVal: v)

proc `%`*[T](elements: openArray[T]): OscValue =
  var arr: seq[OscValue]
  for elem in elements: arr.add(%elem)
  return OscValue(kind: oscArray, arrayVal: arr)
proc `%`*(v: OscValue): OscValue = v

# Converstion between OSC/NTP and Time
# TODO: Move to separate module
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


proc addColor(buffer: var string, val: OscColor) {.inline.} =
  when nimvm:
    buffer.add(val.r)
    buffer.add(val.g)
    buffer.add(val.b)
    buffer.add(val.a)
  else:
    buffer.addUint32(cast[uint32](val))

proc addMidi(buffer: var string, val: OscMidi) {.inline.} =
  when nimvm:
    buffer.add(val.portId)
    buffer.add(val.status)
    buffer.add(val.data1)
    buffer.add(val.data2)
  else:
    buffer.addUint32(cast[uint32](val))


proc addPaddedStr*(buffer: var string, val: string) {.inline.} =
  buffer.add(val)
  # In a string you always want to pad with at least one '\0'
  let rem = 4 - (val.len %% 4)
  for i in 0..<rem: buffer.add('\0')

proc addBlob*(buffer: var string, val: openArray[byte]) {.inline.} =
  # TODO: Use memcpy if possible
  for c in val: buffer.add(c)
  # In a blob you don't need the 0 terminator
  if val.len %% 4 != 0:
    let rem = 4 - (val.len %% 4)
    for i in 0..<rem: buffer.add('\0')

proc readPaddedStr(payload: string, i: var int): string =
  ## Parse OSC String, returning the length of the \0 padded string.
  # TODO: See if we can parse without allocating the string in parseUntil
  # https://nim-lang.org/docs/manual_experimental.html#view-types
  if i >= payload.len:
    raise newException(OscParseError, "Not enough bytes to read string")
  let buf = payload[i..<payload.len]
  let len = buf.parseUntil(result, '\0')
  if len == 0:
    raise newException(OscParseError, "Not enough bytes to read string")
  i += padded4(len + 1) # len + 1 for the \0


proc readOscTime(payload: string, i: var int): OscTime =
  result.seconds = readBe32[uint32](payload, i)
  result.frac = readBe32[uint32](payload, i)


proc readOscColor(payload: string, i: var int): OscColor =
  if i + 4 > payload.len:
    raise newException(OscParseError, "Not enough bytes to read color")
  proc readOscColorSlow(payload: string, i: var int): OscColor =
    result.r = payload[i].byte; inc i
    result.g = payload[i].byte; inc i
    result.b = payload[i].byte; inc i
    result.a = payload[i].byte; inc i
  when defined(nimscript):
    result = readOscColorSlow(payload, i)
  else:
    when nimvm:
      result = readOscColorSlow(payload, i)
    else:
      copyMem(result.addr, payload[i].addr, 4); i += 4


proc readOscMidi(payload: string, i: var int): OscMidi =
  if i + 4 > payload.len:
    raise newException(OscParseError, "Not enough bytes to read midi")
  proc readOscMidiSlow(payload: string, i: var int): OscMidi =
    result.portId = payload[i].byte; inc i
    result.status = payload[i].byte; inc i
    result.data1 = payload[i].byte; inc i
    result.data2 = payload[i].byte; inc i

  when defined(nimscript):
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
  const MAX_ARRAY_DEPTH = 64
  var args: seq[OscValue] = @[]
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
        if length < 0:
          raise newException(OscParseError, "Payload length to be positive")
        if i + length > payload.len:
          raise newException(OscParseError, "Not enough bytes to read blob")
        let val: seq[byte] = @(payload.toOpenArrayByte(i, i+length-1))
        value = OscValue(kind: oscBlob, blobVal: val)
        i += padded4(length)
      of 'T':
        value = OscValue(kind: oscTrue)
      of 'F':
        value = OscValue(kind: oscFalse)
      of 'N':
        value = OscValue(kind: oscNil)
      of '[':
        if depth > MAX_ARRAY_DEPTH:
          raise newException(OscParseError, "Too many nested arrays")
        let arr = readArguments(payload, typeTags, i, j, depth+1)
        value = OscValue(kind: oscArray, arrayVal: arr)
      of ']':
        if depth == 0:
          raise newException(OscParseError, "Unmatched `]`")
        return args
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
        if c.uint32 > char.high.uint32 or c < char.low.uint32:
          raise newException(OscParseError, "Invalid character range: " & $c.uint32)
        value = OscValue(kind: oscChar, charVal: c.char)
      of 'r':
        value = OscValue(kind: oscColor, colorVal: readOscColor(payload, i))
      of 'm':
        value = OscValue(kind: oscMidi, midiVal: readOscMidi(payload, i))
      else:
        # TODO: Add option to surpress this warning or raise error
        # echo "Warning: Unknown type tag: ", t
        continue
    args.add(value)

  return args

func readMessage(data: string, i: var int): OscMessage {.raises: [OscParseError].} =
  ## Parse the given data into an OscMessage object.
  ## Raise an OSCParseError if the data is invalid.
  if i >= data.len:
    raise newException(OscParseError, "Message is too small")
  if data[i] != '/':
    raise newException(OscParseError, "Invalid address, no `/` in the beginning")

  # Read address and type tags
  result.address = readPaddedStr(data, i)
  if i >= data.len:
    return

  # TODO: Maybe this copy can be avoiced too actually
  var typeTags = readPaddedStr(data, i)

  # Parse the payload/values together with the types
  # NOTE: This is kind of ugly passing i and j as var, but it works
  # Need to read some other parsers to see how they do it
  var j: int = 0
  result.args = readArguments(data, typeTags, i, j)


func parseMessage*(data: string): OscMessage {.raises: [OscParseError].} =
  ## Parse the given data into an OscMessage object.
  ## Raise an OSCParseError if the data is invalid.
  var i = 0
  readMessage(data, i)


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

proc addArguments*(buffer: var string, args: seq[OscValue], pad: bool = true) =
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
        addBlob(buffer, arg.blobVal)
      of oscTrue, oscFalse, oscNil, oscInf:
        discard
      of oscArray:
        buffer.addArguments(arg.arrayVal, pad=false)
      of oscTime:
        buffer.addTime(arg.timeVal)
      of oscBigInt:
        buffer.addBe64(arg.bigIntVal)
      of oscDouble:
        buffer.addBe64(arg.doubleVal)
      of oscColor:
        buffer.addColor(arg.colorVal)
      of oscMidi:
        buffer.addMidi(arg.midiVal)
      of oscChar:
        buffer.addBe32(arg.charVal.int32)

proc addMessage*(buffer: var string, msg: OscMessage) =
  ## Write the given OscMessage to a string.
  ## This is the inverse of readMessage.
  buffer.addPaddedStr(msg.address)
  buffer.addPaddedTags(msg.args)
  buffer.addArguments(msg.args)

proc dgram*(msg: OscMessage): string =
  ## Serialize the given OscMessage to a new string and return it.
  var dgram: string = newStringOfCap(512)
  dgram.addMessage(msg)
  return dgram

# TODO: Move into a separate module?
type
  OscPackageKind* = enum
    oscMessage,
    oscBundle

  OscPacket = object
    case kind*: OscPackageKind
    of oscMessage: msg*: OscMessage
    of oscBundle: bundle*: OscBundle

  OscBundle* = object
    time*: OscTime
    contents*: seq[OscPacket]

proc readPacket*(data: string, i: var int): OscPacket

proc readBundle*(data: string, i: var int): OscBundle =
  if data.len < 12:
    raise newException(OscParseError, "Bundle is too small")
  # print(data[i..<i+8])
  if data[i..<i+8].cmp("#bundle\0") != 0:
    raise newException(OscParseError, "Invalid bundle header")
  i += 8

  # Read time tag
  result.time = readOscTime(data, i)

  # Read all bundle elements
  while i < data.len:
    let size = readBe32[int32](data, i)
    if size < 0:
      raise newException(OscParseError, "Bundle size must be positive")
    if i+size > data.len:
      raise newException(OscParseError, "Not enough bytes to read bundle data")
    result.contents.add(readPacket(data, i))


proc readBundle*(data: string): OscBundle =
  var i = 0
  readBundle(data, i)

proc readPacket*(data: string, i: var int) : OscPacket =
  if i+4 > data.len:
    raise newException(OscParseError, "Packet is too small")
  if data[i] == '#':
    result = OscPacket(kind: oscBundle, bundle: readBundle(data, i))
  elif data[i] == '/':
    result = OscPacket(kind: oscMessage, msg: readMessage(data, i))
  else:
    raise newException(OscParseError, "Invalid packet header")

proc readPacket*(data: string): OscPacket =
  var i = 0
  readPacket(data, i)


proc addBundle*(buffer: var string, bundle: OscBundle)

proc addPacket*(buffer: var string, packet: OscPacket) =
  case packet.kind:
    of oscMessage:
      buffer.addMessage(packet.msg)
    of oscBundle:
      buffer.addBundle(packet.bundle)


proc addBundle*(buffer: var string, bundle: OscBundle) =
  ## Serialize the given OscBundle to the given buffer.
  var tmpBuf = newStringOfCap(512)
  buffer.add("#bundle\0")
  buffer.addTime(bundle.time)
  for packet in bundle.contents:
    tmpBuf.addPacket(packet)
    buffer.addBe32(tmpBuf.len.int32)
    buffer.add(tmpBuf)

proc dgram*(msg: OscBundle): string =
  ## Serialize the given OscBundle to a new string and return it.
  var dgram: string = newStringOfCap(512)
  dgram.addBundle(msg)
  return dgram

  # OscMessage("/hello/address", [1.1, "Hello", b"bytes"])


# Prototyping macros/output for more convenient OSC message creation
import macros

macro oscValues(vals: untyped): untyped =
  vals.expectKind(nnkBracket)
  result = newNimNode(nnkBracket)
  for elem in vals:
    var pfx = newNimNode(nnkPrefix)
    var val = elem
    if elem.kind == nnkPrefix and $elem[0] == "%":
      pfx.add(ident("%%"))
      val = elem[1]
    else:
      pfx.add(ident("%"))
    pfx.add(val)
    result.add(pfx)
  echo vals.treeRepr
  echo result.treeRepr

template msg*(addrs: string, arguments: untyped): OscMessage =
  OscMessage(address: addrs, args: @(oscValues(arguments)))


proc `$`*(msg: OscValue): string =
  case msg.kind:
    of oscInt: result = $msg.intVal
    of oscFloat: result = $msg.floatVal
    of oscString: result = '"' & $msg.strVal & '"'
    of oscBlob:
      result.add("%\"")
      for b in msg.blobVal:
        result.add("\\x" & b.toHex())
      result.add("\"")
      # result = "%\"" & $msg.blobVal & '"'
    of oscTrue: result = "true"
    of oscFalse: result = "false"
    of oscInf: result = "OscInf"
    of oscNil: result = "OscNil"
    of oscArray: 
      result.add("[")
      var i = 0
      for e in msg.arrayVal:
        if i > 0:
          result.add(", ")
        result.add($e)
      result.add("]")
    of oscTime: result = $msg.timeVal
    of oscBigInt: result = $msg.bigIntVal
    of oscDouble: result = $msg.doubleVal
    of oscChar: result = '\'' & $msg.charVal & '\''
    of oscColor: result = $msg.colorVal
    of oscMidi: result = $msg.midiVal


proc `$`*(msg: OscMessage): string =
  result.add("msg(\"")
  result.add(msg.address)
  result.add("\", [")
  var i = 0
  for elem in msg.args:
    if i > 0:
      result.add(", ")
    result.add($elem)
    inc i
  result.add("])")

when isMainModule:
  echo msg("/hello/address", [1, "Hello", 3.1415, %"bytes"])
  echo msg("/hello/address", [1, "Hello", 3.141499996185303, %"\x62\x79\x74\x65\x73"])