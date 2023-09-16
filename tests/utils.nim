# Shared test utlities for nosc

import nosc
import nosc/hexprint

template whenJSorVM(isTrue, isFalse: untyped) =
  when nimvm:
    isTrue
  else:
    when (defined(js) or defined(nimdoc) or defined(nimscript)):
      isTrue
    else:
      isFalse

whenJSorVM:
    discard
do:
    import std/random
    import std/times
    var r = initRand(42)
    proc randomTime*(): Time =
        let unixSecs: float64 = r.rand(float64.high)
        fromUnixFloat(unixSecs)

proc roundTripTest*(name: string, message: OscMessage) {.inline.} =
    var buffer = newStringOfCap(512)
    buffer.addMessage(message)
    let parsed = parseMessage(buffer)
    assert buffer.len %% 4 == 0, "Message length is not a multiple of 4"
    if parsed != message:
        echo "Roundtrip test failed for " & name
        echo parsed
        echo message
        echo hexPrint(buffer)
        assert false, "Roundtrip test failed for " & name
