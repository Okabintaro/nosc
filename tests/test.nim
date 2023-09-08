# Unit Tests
# Mostly ported from python-osc
# https://github.com/attwad/python-osc/blob/master/pythonosc/test/test_osc_message.py

import unittest
import nosc

suite "Parsing OSC Messages":
  test "switch rotates (float=?)":
    const DGRAM_KNOB_ROTATES =
        "/FB\x00" &
        ",f\x00\x00" &
        ">xca=q"
    let message = parseMessage(DGRAM_KNOB_ROTATES)
    check(message == OscMessage(address: "/FB", params: @[%0.2425666004419327]))

  test "switch goes off (float=0.0)":
    const DGRAM_SWITCH_GOES_OFF =
        "/SYNC\x00\x00\x00" &
        ",f\x00\x00" &
        "\x00\x00\x00\x00"
    let message = parseMessage(DGRAM_SWITCH_GOES_OFF)
    check(message == OscMessage(address: "/SYNC", params: @[%0.0]))

  test "switch goes on (float=0.5)":
      const DGRAM_SWITCH_GOES_ON = 
          "/SYNC\x00\x00\x00" &
          ",f\x00\x00" &
          "?\x00\x00\x00"
      let message = parseMessage(DGRAM_SWITCH_GOES_ON)
      check(message == OscMessage(address: "/SYNC", params: @[%0.5]))

  test "no parameters":
      const DGRAM_NO_PARAMS = "/SYNC\x00\x00\x00"
      let message = parseMessage(DGRAM_NO_PARAMS)
      check(message == OscMessage(address: "/SYNC", params: @[]))

  test "invalid message":
      const GARBAGE = "AAANO\x00\x00\x00"
      expect(OscParseError):
        discard parseMessage(GARBAGE)

  test "all standard types":
    const DGRAM_ALL_STANDARD_TYPES_OF_PARAMS =
        "/SYNC\x00\x00\x00" &
        ",ifsb\x00\x00\x00" &
        "\x00\x00\x00\x03" &  # 3
        "@\x00\x00\x00" &  # 2.0
        "ABC\x00" & # "ABC"
        "\x00\x00\x00\x08stuff\x00\x00\x00" # b"stuff\x00\x00\x00"

    let message = parseMessage(DGRAM_ALL_STANDARD_TYPES_OF_PARAMS)
    check(message == OscMessage(address: "/SYNC", params: @[%3, %2.0, %"ABC", OscValue(kind: oscBlob, blobVal: "stuff\x00\x00\x00")]))

  test "some non-standard types":
    const DGRAM_ALL_NON_STANDARD_TYPES_OF_PARAMS =
        "/SYNC\x00\x00\x00" &
        "T" &  # True
        "F" &  # False
        "N" &  # Nil
        "[]th\x00" &  # Empty array
        "\x00\x00\x00\x00\x00\x00\x00\x00" &
        "\x00\x00\x00\xe8\xd4\xa5\x10\x00" # 1000000000000
    let message = parseMessage(DGRAM_ALL_NON_STANDARD_TYPES_OF_PARAMS)
    check(message.address == "/SYNC")
    check(message.params.len == 6)
    check(message.params[0] == %true)
    check(message.params[1] == %false)
    check(message.params[2].kind == OscType.oscNil)
    check(message.params[3].kind == OscType.oscArray)
    check(message.params[3].arrayVal.len == 0)

    when false:
      # Python:
      # self.assertEqual((datetime(1900, 1, 1, 0, 0, 0), 0), msg.params[4])
      let expectedDate = dateTime(1900, mJan, 1, zone = utc())
      check(message.params[4].kind == OscType.oscTime)
      check(message.params[4].timeVal == expectedDate)

    check(message.params[5].kind == OscType.oscBigInt)
    check(message.params[5].bigIntVal == 1000000000000)

    test "complex array params":
      const DGRAM_COMPLEX_ARRAY_PARAMS = 
        "/SYNC\x00\x00\x00" &
        ",[i][[ss]][[i][i[s]]]\x00\x00\x00" &
        "\x00\x00\x00\x01" &  # 1
        "ABC\x00" &  # "ABC"
        "DEF\x00" &  # "DEF"
        "\x00\x00\x00\x02" &  # 2
        "\x00\x00\x00\x03" &  # 3
        "GHI\x00"  # "GHI"
      let message = parseMessage(DGRAM_COMPLEX_ARRAY_PARAMS)
      check(message.address == "/SYNC")
      check(message.params.len == 3)
      check(message.params[0].kind == OscType.oscArray)
      check(message.params[0].arrayVal ==  @[OscValue(kind: oscInt, intVal: 1)])
      check(message.params[1].kind == OscType.oscArray)
      check(message.params[1].arrayVal == @[OscValue(kind: oscArray, arrayVal: @[OscValue(kind: oscString, strVal: "ABC"), OscValue(kind: oscString, strVal: "DEF")])])
      check(message.params[2].kind == OscType.oscArray)
      let expected = %[%[2], %[%3, %[%"GHI"]]]
      check(message.params[2] == expected)

  test "ignore unknown parameter":
    const DGRAM_UNKNOWN_PARAM_TYPE = 
      "/SYNC\x00\x00\x00" &
      ",fx\x00" &  # x is an unknown param type.
      "?\x00\x00\x00"
    let msg = parseMessage(DGRAM_UNKNOWN_PARAM_TYPE)
    check(msg.address == "/SYNC")
    check(msg.params.len == 1)
    check(msg.params[0] == %0.5)

  test "parse long params list":
    const DGRAM_LONG_LIST = "/SYNC\x00\x00\x00,[iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii]\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x02\x00\x00\x00\x03\x00\x00\x00\x04\x00\x00\x00\x05\x00\x00\x00\x06\x00\x00\x00\x07\x00\x00\x00\x08\x00\x00\x00\t\x00\x00\x00\n\x00\x00\x00\x0b\x00\x00\x00\x0c\x00\x00\x00\r\x00\x00\x00\x0e\x00\x00\x00\x0f\x00\x00\x00\x10\x00\x00\x00\x11\x00\x00\x00\x12\x00\x00\x00\x13\x00\x00\x00\x14\x00\x00\x00\x15\x00\x00\x00\x16\x00\x00\x00\x17\x00\x00\x00\x18\x00\x00\x00\x19\x00\x00\x00\x1a\x00\x00\x00\x1b\x00\x00\x00\x1c\x00\x00\x00\x1d\x00\x00\x00\x1e\x00\x00\x00\x1f\x00\x00\x00 \x00\x00\x00!\x00\x00\x00\"\x00\x00\x00#\x00\x00\x00$\x00\x00\x00%\x00\x00\x00&\x00\x00\x00\'\x00\x00\x00(\x00\x00\x00)\x00\x00\x00*\x00\x00\x00+\x00\x00\x00,\x00\x00\x00-\x00\x00\x00.\x00\x00\x00/\x00\x00\x000\x00\x00\x001\x00\x00\x002\x00\x00\x003\x00\x00\x004\x00\x00\x005\x00\x00\x006\x00\x00\x007\x00\x00\x008\x00\x00\x009\x00\x00\x00:\x00\x00\x00;\x00\x00\x00<\x00\x00\x00=\x00\x00\x00>\x00\x00\x00?\x00\x00\x00@\x00\x00\x00A\x00\x00\x00B\x00\x00\x00C\x00\x00\x00D\x00\x00\x00E\x00\x00\x00F\x00\x00\x00G\x00\x00\x00H\x00\x00\x00I\x00\x00\x00J\x00\x00\x00K\x00\x00\x00L\x00\x00\x00M\x00\x00\x00N\x00\x00\x00O\x00\x00\x00P\x00\x00\x00Q\x00\x00\x00R\x00\x00\x00S\x00\x00\x00T\x00\x00\x00U\x00\x00\x00V\x00\x00\x00W\x00\x00\x00X\x00\x00\x00Y\x00\x00\x00Z\x00\x00\x00[\x00\x00\x00\\\x00\x00\x00]\x00\x00\x00^\x00\x00\x00_\x00\x00\x00`\x00\x00\x00a\x00\x00\x00b\x00\x00\x00c\x00\x00\x00d\x00\x00\x00e\x00\x00\x00f\x00\x00\x00g\x00\x00\x00h\x00\x00\x00i\x00\x00\x00j\x00\x00\x00k\x00\x00\x00l\x00\x00\x00m\x00\x00\x00n\x00\x00\x00o\x00\x00\x00p\x00\x00\x00q\x00\x00\x00r\x00\x00\x00s\x00\x00\x00t\x00\x00\x00u\x00\x00\x00v\x00\x00\x00w\x00\x00\x00x\x00\x00\x00y\x00\x00\x00z\x00\x00\x00{\x00\x00\x00|\x00\x00\x00}\x00\x00\x00~\x00\x00\x00\x7f\x00\x00\x00\x80\x00\x00\x00\x81\x00\x00\x00\x82\x00\x00\x00\x83\x00\x00\x00\x84\x00\x00\x00\x85\x00\x00\x00\x86\x00\x00\x00\x87\x00\x00\x00\x88\x00\x00\x00\x89\x00\x00\x00\x8a\x00\x00\x00\x8b\x00\x00\x00\x8c\x00\x00\x00\x8d\x00\x00\x00\x8e\x00\x00\x00\x8f\x00\x00\x00\x90\x00\x00\x00\x91\x00\x00\x00\x92\x00\x00\x00\x93\x00\x00\x00\x94\x00\x00\x00\x95\x00\x00\x00\x96\x00\x00\x00\x97\x00\x00\x00\x98\x00\x00\x00\x99\x00\x00\x00\x9a\x00\x00\x00\x9b\x00\x00\x00\x9c\x00\x00\x00\x9d\x00\x00\x00\x9e\x00\x00\x00\x9f\x00\x00\x00\xa0\x00\x00\x00\xa1\x00\x00\x00\xa2\x00\x00\x00\xa3\x00\x00\x00\xa4\x00\x00\x00\xa5\x00\x00\x00\xa6\x00\x00\x00\xa7\x00\x00\x00\xa8\x00\x00\x00\xa9\x00\x00\x00\xaa\x00\x00\x00\xab\x00\x00\x00\xac\x00\x00\x00\xad\x00\x00\x00\xae\x00\x00\x00\xaf\x00\x00\x00\xb0\x00\x00\x00\xb1\x00\x00\x00\xb2\x00\x00\x00\xb3\x00\x00\x00\xb4\x00\x00\x00\xb5\x00\x00\x00\xb6\x00\x00\x00\xb7\x00\x00\x00\xb8\x00\x00\x00\xb9\x00\x00\x00\xba\x00\x00\x00\xbb\x00\x00\x00\xbc\x00\x00\x00\xbd\x00\x00\x00\xbe\x00\x00\x00\xbf\x00\x00\x00\xc0\x00\x00\x00\xc1\x00\x00\x00\xc2\x00\x00\x00\xc3\x00\x00\x00\xc4\x00\x00\x00\xc5\x00\x00\x00\xc6\x00\x00\x00\xc7\x00\x00\x00\xc8\x00\x00\x00\xc9\x00\x00\x00\xca\x00\x00\x00\xcb\x00\x00\x00\xcc\x00\x00\x00\xcd\x00\x00\x00\xce\x00\x00\x00\xcf\x00\x00\x00\xd0\x00\x00\x00\xd1\x00\x00\x00\xd2\x00\x00\x00\xd3\x00\x00\x00\xd4\x00\x00\x00\xd5\x00\x00\x00\xd6\x00\x00\x00\xd7\x00\x00\x00\xd8\x00\x00\x00\xd9\x00\x00\x00\xda\x00\x00\x00\xdb\x00\x00\x00\xdc\x00\x00\x00\xdd\x00\x00\x00\xde\x00\x00\x00\xdf\x00\x00\x00\xe0\x00\x00\x00\xe1\x00\x00\x00\xe2\x00\x00\x00\xe3\x00\x00\x00\xe4\x00\x00\x00\xe5\x00\x00\x00\xe6\x00\x00\x00\xe7\x00\x00\x00\xe8\x00\x00\x00\xe9\x00\x00\x00\xea\x00\x00\x00\xeb\x00\x00\x00\xec\x00\x00\x00\xed\x00\x00\x00\xee\x00\x00\x00\xef\x00\x00\x00\xf0\x00\x00\x00\xf1\x00\x00\x00\xf2\x00\x00\x00\xf3\x00\x00\x00\xf4\x00\x00\x00\xf5\x00\x00\x00\xf6\x00\x00\x00\xf7\x00\x00\x00\xf8\x00\x00\x00\xf9\x00\x00\x00\xfa\x00\x00\x00\xfb\x00\x00\x00\xfc\x00\x00\x00\xfd\x00\x00\x00\xfe\x00\x00\x00\xff\x00\x00\x01\x00\x00\x00\x01\x01\x00\x00\x01\x02\x00\x00\x01\x03\x00\x00\x01\x04\x00\x00\x01\x05\x00\x00\x01\x06\x00\x00\x01\x07\x00\x00\x01\x08\x00\x00\x01\t\x00\x00\x01\n\x00\x00\x01\x0b\x00\x00\x01\x0c\x00\x00\x01\r\x00\x00\x01\x0e\x00\x00\x01\x0f\x00\x00\x01\x10\x00\x00\x01\x11\x00\x00\x01\x12\x00\x00\x01\x13\x00\x00\x01\x14\x00\x00\x01\x15\x00\x00\x01\x16\x00\x00\x01\x17\x00\x00\x01\x18\x00\x00\x01\x19\x00\x00\x01\x1a\x00\x00\x01\x1b\x00\x00\x01\x1c\x00\x00\x01\x1d\x00\x00\x01\x1e\x00\x00\x01\x1f\x00\x00\x01 \x00\x00\x01!\x00\x00\x01\"\x00\x00\x01#\x00\x00\x01$\x00\x00\x01%\x00\x00\x01&\x00\x00\x01\'\x00\x00\x01(\x00\x00\x01)\x00\x00\x01*\x00\x00\x01+\x00\x00\x01,\x00\x00\x01-\x00\x00\x01.\x00\x00\x01/\x00\x00\x010\x00\x00\x011\x00\x00\x012\x00\x00\x013\x00\x00\x014\x00\x00\x015\x00\x00\x016\x00\x00\x017\x00\x00\x018\x00\x00\x019\x00\x00\x01:\x00\x00\x01;\x00\x00\x01<\x00\x00\x01=\x00\x00\x01>\x00\x00\x01?\x00\x00\x01@\x00\x00\x01A\x00\x00\x01B\x00\x00\x01C\x00\x00\x01D\x00\x00\x01E\x00\x00\x01F\x00\x00\x01G\x00\x00\x01H\x00\x00\x01I\x00\x00\x01J\x00\x00\x01K\x00\x00\x01L\x00\x00\x01M\x00\x00\x01N\x00\x00\x01O\x00\x00\x01P\x00\x00\x01Q\x00\x00\x01R\x00\x00\x01S\x00\x00\x01T\x00\x00\x01U\x00\x00\x01V\x00\x00\x01W\x00\x00\x01X\x00\x00\x01Y\x00\x00\x01Z\x00\x00\x01[\x00\x00\x01\\\x00\x00\x01]\x00\x00\x01^\x00\x00\x01_\x00\x00\x01`\x00\x00\x01a\x00\x00\x01b\x00\x00\x01c\x00\x00\x01d\x00\x00\x01e\x00\x00\x01f\x00\x00\x01g\x00\x00\x01h\x00\x00\x01i\x00\x00\x01j\x00\x00\x01k\x00\x00\x01l\x00\x00\x01m\x00\x00\x01n\x00\x00\x01o\x00\x00\x01p\x00\x00\x01q\x00\x00\x01r\x00\x00\x01s\x00\x00\x01t\x00\x00\x01u\x00\x00\x01v\x00\x00\x01w\x00\x00\x01x\x00\x00\x01y\x00\x00\x01z\x00\x00\x01{\x00\x00\x01|\x00\x00\x01}\x00\x00\x01~\x00\x00\x01\x7f\x00\x00\x01\x80\x00\x00\x01\x81\x00\x00\x01\x82\x00\x00\x01\x83\x00\x00\x01\x84\x00\x00\x01\x85\x00\x00\x01\x86\x00\x00\x01\x87\x00\x00\x01\x88\x00\x00\x01\x89\x00\x00\x01\x8a\x00\x00\x01\x8b\x00\x00\x01\x8c\x00\x00\x01\x8d\x00\x00\x01\x8e\x00\x00\x01\x8f\x00\x00\x01\x90\x00\x00\x01\x91\x00\x00\x01\x92\x00\x00\x01\x93\x00\x00\x01\x94\x00\x00\x01\x95\x00\x00\x01\x96\x00\x00\x01\x97\x00\x00\x01\x98\x00\x00\x01\x99\x00\x00\x01\x9a\x00\x00\x01\x9b\x00\x00\x01\x9c\x00\x00\x01\x9d\x00\x00\x01\x9e\x00\x00\x01\x9f\x00\x00\x01\xa0\x00\x00\x01\xa1\x00\x00\x01\xa2\x00\x00\x01\xa3\x00\x00\x01\xa4\x00\x00\x01\xa5\x00\x00\x01\xa6\x00\x00\x01\xa7\x00\x00\x01\xa8\x00\x00\x01\xa9\x00\x00\x01\xaa\x00\x00\x01\xab\x00\x00\x01\xac\x00\x00\x01\xad\x00\x00\x01\xae\x00\x00\x01\xaf\x00\x00\x01\xb0\x00\x00\x01\xb1\x00\x00\x01\xb2\x00\x00\x01\xb3\x00\x00\x01\xb4\x00\x00\x01\xb5\x00\x00\x01\xb6\x00\x00\x01\xb7\x00\x00\x01\xb8\x00\x00\x01\xb9\x00\x00\x01\xba\x00\x00\x01\xbb\x00\x00\x01\xbc\x00\x00\x01\xbd\x00\x00\x01\xbe\x00\x00\x01\xbf\x00\x00\x01\xc0\x00\x00\x01\xc1\x00\x00\x01\xc2\x00\x00\x01\xc3\x00\x00\x01\xc4\x00\x00\x01\xc5\x00\x00\x01\xc6\x00\x00\x01\xc7\x00\x00\x01\xc8\x00\x00\x01\xc9\x00\x00\x01\xca\x00\x00\x01\xcb\x00\x00\x01\xcc\x00\x00\x01\xcd\x00\x00\x01\xce\x00\x00\x01\xcf\x00\x00\x01\xd0\x00\x00\x01\xd1\x00\x00\x01\xd2\x00\x00\x01\xd3\x00\x00\x01\xd4\x00\x00\x01\xd5\x00\x00\x01\xd6\x00\x00\x01\xd7\x00\x00\x01\xd8\x00\x00\x01\xd9\x00\x00\x01\xda\x00\x00\x01\xdb\x00\x00\x01\xdc\x00\x00\x01\xdd\x00\x00\x01\xde\x00\x00\x01\xdf\x00\x00\x01\xe0\x00\x00\x01\xe1\x00\x00\x01\xe2\x00\x00\x01\xe3\x00\x00\x01\xe4\x00\x00\x01\xe5\x00\x00\x01\xe6\x00\x00\x01\xe7\x00\x00\x01\xe8\x00\x00\x01\xe9\x00\x00\x01\xea\x00\x00\x01\xeb\x00\x00\x01\xec\x00\x00\x01\xed\x00\x00\x01\xee\x00\x00\x01\xef\x00\x00\x01\xf0\x00\x00\x01\xf1\x00\x00\x01\xf2\x00\x00\x01\xf3\x00\x00\x01\xf4\x00\x00\x01\xf5\x00\x00\x01\xf6\x00\x00\x01\xf7\x00\x00\x01\xf8\x00\x00\x01\xf9\x00\x00\x01\xfa\x00\x00\x01\xfb\x00\x00\x01\xfc\x00\x00\x01\xfd\x00\x00\x01\xfe\x00\x00\x01\xff"
    let msg = parseMessage(DGRAM_LONG_LIST)
    check(msg.address == "/SYNC")
    check(msg.params.len == 1)
    check(msg.params[0].arrayVal.len == 512)

  # test "too long params":
    # NOTE: I somehow broke the parser, playing around with the DRAM_LONG_LIST
    #       addrLen: 8152 8150
    #   C:\Users\Okabintaro\nosc\tests\test.nim(138) test
    #   C:\Users\Okabintaro\nosc\src\nosc.nim(174) parseMessage
    #   C:\Users\Okabintaro\scoop\apps\nim\current\lib\system\indices.nim(85) []
    #   C:\Users\Okabintaro\scoop\apps\nim\current\lib\system\fatal.nim(53) sysFatal
    # Unhandled exception: value out of range: -2 notin 0 .. 9223372036854775807 [RangeDefect]
    # TODO: Need to reproduce/fuzz it

# TODO
# suite "Building OSC Messages":
#   test "build simple message(float)":
#     const DGRAM_SWITCH_GOES_ON = 
#         "/SYNC\x00\x00\x00" &
#         ",f\x00\x00" &
#         "?\x00\x00\x00"
#     let message = OscMessage(address: "/SYNC", params: @[OscValue(kind: oscFloat, floatVal: 1.0)])
#     check(message.dgram() == "/SYNC\x00\x00\x00,f\x00\x00\x00?\x00\x00\x00")
