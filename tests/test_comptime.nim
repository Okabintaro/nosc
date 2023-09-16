import nosc
import utils

# Compile time roundTrip Test
static:
    # Standard Types
    roundTripTest "Int", OscMessage(address: "/SYNC", params: @[%123123])
    roundTripTest "Float", OscMessage(address: "/SYNC", params: @[%1.0])
    roundTripTest "String", OscMessage(address: "/SYNC", params: @[%"Hello World!"])
    roundTripTest "Blob", OscMessage(address: "/SYNC", params: @[%%"stuff\x00\x00\x00"])

    # Non Standard Types
    roundTripTest "Double", OscMessage(address: "/SYNC", params: @[%42.1337.toOscDouble])
    roundTripTest "NonDataTypes/Flags", OscMessage(address: "/SYNC", params: @[%true, %false, %OscNil, %OscInf])
    roundTripTest "Arrays", OscMessage(address: "/SYNC", params: @[%[%[2], %[%3, %[%"GHI"]]]])
    roundTripTest "Time", OscMessage(address: "/SYNC", params: @[%OscTimeImmediate])
    roundTripTest "Int64", OscMessage(address: "/SYNC", params: @[%123123123.int64])
    roundTripTest "Char", OscMessage(address: "/SYNC", params: @[%'H', %'e', %'l', %'l', %'o'])
    roundTripTest "Color/RGBA", OscMessage(address: "/SYNC", params: @[%OscColor(r: 0x12, g: 0x34, b: 0x56, a: 0x78)])
    roundTripTest "Midi", OscMessage(address: "/SYNC", params: @[%OscMidi(portId: 1, status: 0xAB, data1: 0xCD, data2: 0xEF)])
 
    echo "Compile time tests passed!"
