import std/strformat

version     = "0.1.0"
author      = "Okabintaro"
description = "Pure Nim implementation of the OSC(Open Sound Control) protocol"
license     = "MIT"

srcDir = "src"
bin    = @["noscat", "noscsend"]
installExt = @["nim"]

requires "nim >= 2.0.0"

task test, "Runs the test suite":
  exec "nim c -r tests/test_messages.nim"
  exec "nim c -r tests/test_time.nim"
  # exec "nim c -r tests/test_bundles.nim"

  # Test compile time execution and nimscript
  exec "nim c -r tests/test_comptime.nim"
  exec "nim e tests/test_comptime.nim"

task bench, "Runs the benchmark suite":
  exec "nim c -r tests/bench.nim"

# Cross compile static binaries easily using zig cc!
# https://nim-lang.org/docs/nimc.html#crossminuscompilation
# https://github.com/enthus1ast/zigcc
# TODO: Clean this mess up
func zigcc(file: string, target: string, os: string): string =
  var flags = &"--forceBuild:on --os:{os} --passL:-static --mm:arc -d:release --opt:size"
  # Those don't seem to work on windows
  let expflags = "--passC:-flto --passL:-flto --passL:-Wl,-dead_strip"
  if os == "linux":
    flags = flags & " " & expflags
  var cmd = "nim c --cc:clang --clang.exe=\"zigcc\" --clang.linkerexe=\"zigcc\" " & flags & " "
  cmd.add("--passC:\"-target " & target & "\" " &  "--passL:\"-target " & target & "\" ")
  let ext = if os == "windows": ".exe" else: ""
  cmd.add(&"--out:./bin/noscat.{target}{ext} ")
  cmd.add(file)
  return cmd

task staticbuild, "Build statically linked executables using zigcc":
  exec zigcc("src/noscat.nim", "x86_64-linux-musl", "linux")
  exec zigcc("src/noscat.nim", "x86_64-windows-gnu", "windows")
  exec zigcc("src/noscat.nim", "x86_64-macos-none", "macosx")

task py, "Build and test python bindings":
  if hostOS == "windows":
    exec "nim c --app:lib --mm:arc -d:release --threads:on --tlsEmulation:off --passL:-static --out:py/noscpy.pyd py/noscpy.nim"
  else:
    exec "nim c --app:lib --mm:arc -d:release --threads:on --out:py/noscpy.so py/noscpy.nim"
  exec "python3 py/test_bindings.py"

task pyproptest, "Run property tests using python bindings and hypothesis":
  if hostOS == "windows":
    exec "nim c --app:lib --mm:arc -d:debug --opt:speed --threads:on --tlsEmulation:off --passL:-static --out:tests/noscpy.pyd py/noscpy.nim"
  else:
    exec "nim c --app:lib --mm:arc -d:debug --opt:speed --threads:on --out:tests/noscpy.so py/noscpy.nim"
  exec "python3 tests/proptest.py"


task fuzz, "Fuzz the osc parser using drchaos":
  exec """nim --cc:clang -d:useMalloc -t:"-fsanitize=fuzzer,address,undefined" -l:"-fsanitize=fuzzer,address,undefined" -d:release -d:nosignalhandler --threads:off --nomain:on -g --mm:arc c tests/fuzz.nim"""
  exec "./tests/fuzz"


taskRequires "fuzz", "drchaos"
taskRequires "py", "nimpy"
taskRequires "pyproptest", "https://github.com/Okabintaro/nimpy#512e0972a"
