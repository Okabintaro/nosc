import std/strformat

version     = "0.1.0"
author      = "Okabintaro"
description = "Pure Nim implementation of the OSC(Open Sound Control) protocol"
license     = "MIT"

srcDir = "src"
bin    = @["noscat", "noscsend"]
installExt = @["nim"]

requires "nim >= 1.2.2", "nimpy"


requires "nim >= 1.2.2"

task test, "Runs the test suite":
  exec "nim c -r tests/test.nim"

  # Test compile time execution and nimscript
  exec "nim c -r tests/comptests.nim"
  exec "nim e tests/comptests.nim"

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
  exec "nim c --app:lib --mm:arc --opt:size --threads:on --out:py/noscpy.so py/noscpy.nim"
  exec "python3 py/test_bindings.py"