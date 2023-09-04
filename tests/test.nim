# Unit Tests
# Mostly ported from python-osc
# https://github.com/attwad/python-osc/blob/master/pythonosc/test/test_osc_message.py

import unittest
import nosc
# import std/times

suite "Parsing OSC Messages":

  test "switch rotates (float=?)":
    const DGRAM_KNOB_ROTATES =
        "/FB\x00" &
        ",f\x00\x00" &
        ">xca=q"
    let message = parseMessage(DGRAM_KNOB_ROTATES)
    check(message.address == "/FB")
    check(message.params.len == 1)
    check(message.params[0].kind == OscType.oscFloat)

  test "switch goes off (float=0.0)":
    const DGRAM_SWITCH_GOES_OFF =
        "/SYNC\x00\x00\x00" &
        ",f\x00\x00" &
        "\x00\x00\x00\x00"
    let message = parseMessage(DGRAM_SWITCH_GOES_OFF)
    check(message.address == "/SYNC")
    check(message.params.len == 1)
    check(message.params[0].kind == OscType.oscFloat)
    check(message.params[0].floatVal == 0.0)

  test "switch goes on (float=0.5)":
      const DGRAM_SWITCH_GOES_ON = 
          "/SYNC\x00\x00\x00" &
          ",f\x00\x00" &
          "?\x00\x00\x00"
      let message = parseMessage(DGRAM_SWITCH_GOES_ON)
      check(message.address == "/SYNC")
      check(message.params.len == 1)
      check(message.params[0].kind == OscType.oscFloat)
      check(message.params[0].floatVal == 0.5)

  test "no parameters":
      const DGRAM_NO_PARAMS = "/SYNC\x00\x00\x00"
      let message = parseMessage(DGRAM_NO_PARAMS)
      check(message.address == "/SYNC")
      check(message.params.len == 0)

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
    check(message.address == "/SYNC")
    check(message.params.len == 4)
    check(message.params[0].kind == OscType.oscInt)
    check(message.params[0].intVal == 3)
    check(message.params[1].kind == OscType.oscFloat)
    check(message.params[1].floatVal == 2.0)
    check(message.params[2].kind == OscType.oscString)
    check(message.params[2].strVal == "ABC")
    check(message.params[3].kind == OscType.oscBlob)
    check(message.params[3].blobVal == "stuff\x00\x00\x00")

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
    check(message.params[0].kind == OscType.oscTrue)
    check(message.params[1].kind == OscType.oscFalse)
    check(message.params[2].kind == OscType.oscNil)

    # TODO: Implement those
    when false:
        check(message.params[3].kind == OscType.oscArray)
        check(message.params[3].arrayVal == @[])

        # Python:
        # self.assertEqual((datetime(1900, 1, 1, 0, 0, 0), 0), msg.params[4])
        let expectedDate = dateTime(1900, mJan, 1, zone = utc())
        check(message.params[4].kind == OscType.oscTime)
        check(message.params[4].timeVal == expectedDate)

        check(message.params[5].kind == OscType.oscBigInt)
        check(message.params[5].bigIntVal == 1000000000000)
