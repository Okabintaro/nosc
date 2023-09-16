## Unit Tests for bundles
## Mostly ported from python-osc
## https://github.com/attwad/python-osc/blob/master/pythonosc/test/test_osc_bundle.py

import unittest
import nosc
import nosc/hexprint
import pretty

suite "pythonosc.test.test_osc_bundle":
  test "test_datagram_length":
    const DGRAM_KNOB_ROTATES_BUNDLE =
        "#bundle\x00" &
        "\x00\x00\x00\x00\x00\x00\x00\x01" & 
        "\x00\x00\x00\x14" &
        "/LFO_Rate\x00\x00\x00" &
        ",f\x00\x00" &
        ">\x8c\xcc\xcd"
    let bundle = DGRAM_KNOB_ROTATES_BUNDLE.readBundle()
    let dgram = bundle.dgram()
    print(bundle)
    check(dgram.len == DGRAM_KNOB_ROTATES_BUNDLE.len)
    check(bundle.time.isImmediate)

# TODO:
# suite "Bundle Round Trip Tests":