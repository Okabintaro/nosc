import nosc
import utils

# Compile time roundTrip Test
static:
    # Standard Types
    roundTripTest "Int", OscMessage(address: "/SYNC", args: @[%123123])
    roundTripTest "Float", OscMessage(address: "/SYNC", args: @[%1.0])
    roundTripTest "String", OscMessage(address: "/SYNC", args: @[%"Hello World!"])
    roundTripTest "Blob", OscMessage(address: "/SYNC", args: @[%%"stuff\x00\x00\x00"])

    # Non Standard Types
    roundTripTest "Double", OscMessage(address: "/SYNC", args: @[%42.1337.toOscDouble])
    roundTripTest "NonDataTypes/Flags", OscMessage(address: "/SYNC", args: @[%true, %false, %OscNil, %OscInf])
    roundTripTest "Arrays", OscMessage(address: "/SYNC", args: @[%[%[2], %[%3, %[%"GHI"]]]])
    roundTripTest "Time", OscMessage(address: "/SYNC", args: @[%OscTimeImmediate])
    roundTripTest "Int64", OscMessage(address: "/SYNC", args: @[%123123123.int64])
    roundTripTest "Char", OscMessage(address: "/SYNC", args: @[%'H', %'e', %'l', %'l', %'o'])
    roundTripTest "Color/RGBA", OscMessage(address: "/SYNC", args: @[%OscColor(r: 0x12, g: 0x34, b: 0x56, a: 0x78)])
    roundTripTest "Midi", OscMessage(address: "/SYNC", args: @[%OscMidi(portId: 1, status: 0xAB, data1: 0xCD, data2: 0xEF)])
 
    echo "Compile time tests passed!"
