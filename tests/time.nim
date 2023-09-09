# Tests for ntp/osc timestamps

import unittest
import nosc
import std/times
import std/random

var r = initRand(42)

const MAX: float64 = 1694250471.444104

proc randomTime(): Time =
  let unixSecs: float64 = r.rand(MAX)
  fromUnixFloat(unixSecs)


const SAMPLES = 100

suite "NTP/OSC Timestamps":
  test "fractional part round-trip":
    # Given a random fraction do a roundtrip test and check if the result is the same
    # There seems to be only a deviation of 5 ticks!
    for i in 1..SAMPLES:
      let frac: uint32 = r.rand(uint32.high).uint32
      let nanos = fractionToNano(frac)
      let frac2 = nanoToFraction(nanos)
      let diff = frac.int - frac2.int
      check(abs(diff) <= 5)
  test "nanoseconds round-trip":
    # Given a random number of nanoseconds do a roundtrip test and check if the result is the same
    # There seems to be only a deviation of 1 nanosecond!
    for i in 1..SAMPLES:
      let nanos: uint32 = r.rand(NanosecondRange.high).uint32
      let frac = nanoToFraction(nanos)
      let nanos2 = fractionToNano(frac)
      let diff = nanos.int - nanos2.int
      check(abs(diff) <= 1)
  test "time round-trip":
    # Given random timestamps do a roundtrip test and check if the result is the same
    for i in 1..SAMPLES:
      let t = randomTime()
      let oscTime = t.toOscTime()
      let t2 = oscTime.toTime()
      check(t.toUnix() == t2.toUnix())

      # This should follow from the Nanos test above already but still check
      let nanoDiff = t.nanosecond - t2.nanosecond
      check(abs(nanoDiff) <= 1)



