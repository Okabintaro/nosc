import nosc
import nosc/hexprint
when not (defined(windows) and defined(nimscript)):
  import std/times

# Compile time roundTrip Test
proc roundTripTest(name: string, message: OscMessage) {.inline.} =
  var buffer = newStringOfCap(512)
  let len = buffer.writeMessage(message)
  let parsed = parseMessage(buffer)
  assert len %% 4 == 0, "Message length is not a multiple of 4"
  if parsed != message:
    echo "Roundtrip test failed for " & name
    echo "original: ", message
    echo "parsed:   ", parsed
    echo "datagram: ", hexPrint(buffer)


const DGRAM_KNOB_ROTATES =
    "/FB\x00" &
    ",d\x00\x00" &
    "@E\x11\x1d\x14\xe3\xbc\xd3"
let message = parseMessage(DGRAM_KNOB_ROTATES)
echo message
# assert(message == OscMessage(address: "/FB", params: @[42.1337.toOscDouble]))


# # Standard Types
when false:
  roundTripTest "Int", OscMessage(address: "/SYNC", params: @[%11231312312312])
  roundTripTest "String", OscMessage(address: "/SYNC", params: @[%"Hello World!"])
  const test_blob = OscValue(kind: oscBlob, blobVal: "stuff\x00\x00\x00")
  roundTripTest "Blob", OscMessage(address: "/SYNC", params: @[test_blob])

  # Non Standard Types
  roundTripTest "NonDataTypes/Flags", OscMessage(address: "/SYNC", params: @[%true, %false, %OscNil, %OscInf])
  roundTripTest "Arrays", OscMessage(address: "/SYNC", params: @[%[%[2], %[%3, %[%"GHI"]]]])

  when not (defined(windows) and defined(nimscript)):
    const time = initTime(123123, 23123)
    roundTripTest "Time", OscMessage(address: "/SYNC", params: @[%time])

  roundTripTest "Int64", OscMessage(address: "/SYNC", params: @[%int64.low])
  roundTripTest "Char", OscMessage(address: "/SYNC", params: @[%'H', %'e', %'l', %'l', %'o'])
  roundTripTest "Color/RGBA", OscMessage(address: "/SYNC", params: @[%OscColor(r: 0x12, g: 0x34, b: 0x56, a: 0x78)])
  roundTripTest "Midi", OscMessage(address: "/SYNC", params: @[%OscMidi(portId: 1, status: 0xAB, data1: 0xCD, data2: 0xEF)])

roundTripTest "Float", OscMessage(address: "/SYNC", params: @[%42.69])
roundTripTest "Double", OscMessage(address: "/SYNC", params: @[42.1337.toOscDouble()])