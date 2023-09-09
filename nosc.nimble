version     = "0.1.0"
author      = "Okabintaro"
description = "Pure Nim implementation of the OSC(Open Sound Control) protocol"
license     = "MIT"

srcDir = "src"
bin    = @["noscat", "noscsend"]

requires "nim >= 1.2.2"

task test, "Runs the test suite":
  exec "nim c -r tests/test.nim"

  # Test compile time execution and nimscript
  exec "nim c -r tests/comptests.nim"
  exec "nim e tests/comptests.nim"

task bench, "Runs the benchmark suite":
  exec "nim c -r tests/bench.nim"
