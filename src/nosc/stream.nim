## Routines for writing/parsing binary data
## 
## This contains routines like swap from [flatty](https://github.com/treeform/flatty) from Andre von Houck, licensed unter MIT.
## (The license is included in the source code below/not in the documentation).
## 
## I adapted the code to make it compatible with nimscript and nimvm for compile time execution.
## Unfortunately this made the code quite a bit ugly.

# The MIT License (MIT)
# 
# Copyright (c) 2021 Andre von Houck
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import errors

type Bit32Type = int32 | uint32 | float32
type Bit64Type = int64 | uint64 | float64

when system.cpuEndian == littleEndian:
  func swap*(v: uint16): uint16 {.inline.} =
    let tmp = cast[array[2, uint8]](v)
    (tmp[0].uint16 shl 8) or tmp[1].uint16

  func swap*(v: uint32): uint32 {.inline.} =
    when nimvm:
      ((v and (0xFF.uint32 shl 0)) shl 24) +
      ((v and (0xFF.uint32 shl 8)) shl 8) +
      ((v and (0xFF.uint32 shl 16)) shr 8) +
      ((v and (0xFF.uint32 shl 24)) shr 24)
    else:
      let tmp = cast[array[2, uint16]](v)
      (swap(tmp[0]).uint32 shl 16) or swap(tmp[1])

  func swap*(v: uint64): uint64 {.inline.} =
    when nimvm:
      ((v and (0xFF.uint64 shl 0)) shl 56) +
      ((v and (0xFF.uint64 shl 8)) shl 40) +
      ((v and (0xFF.uint64 shl 16)) shl 24) +
      ((v and (0xFF.uint64 shl 24)) shl 8) +
      ((v and (0xFF.uint64 shl 32)) shr 8) +
      ((v and (0xFF.uint64 shl 40)) shr 24) +
      ((v and (0xFF.uint64 shl 48)) shr 40) +
      ((v and (0xFF.uint64 shl 56)) shr 56)
    else:
      let tmp = cast[array[2, uint32]](v)
      (swap(tmp[0]).uint64 shl 32) or swap(tmp[1])

  func swap*(v: int32): int32 {.inline.} =
    cast[int32](cast[uint32](v).swap())

  func swap*(v: int64): int64 {.inline.} =
    cast[int64](cast[uint64](v).swap())

  func swap*(v: float32): float32 {.inline.} =
    cast[float32](cast[uint32](v).swap())

  func swap*(v: float64): float64 {.inline.} =
    cast[float64](cast[uint64](v).swap())
else:
  func swap*[T](v: T): T {.inline.} =
    v


func addUint32*(s: var string, v: uint32) {.inline.} =
  func addUint32Slow(s: var string, v: uint32) {.inline.} =
    s.add ((v and 0x000000FF'u32) shr 0).char
    s.add ((v and 0x0000FF00'u32) shr 8).char
    s.add ((v and 0x00FF0000'u32) shr 16).char
    s.add ((v and 0xFF000000'u32) shr 24).char

  when defined(nimscript):
    addUint32Slow(s, v)
  else:
    when nimvm:
      addUint32Slow(s, v)
    else:
      # Fast path for native
      s.setLen(s.len + sizeof(v))
      copyMem(s[s.len - sizeof(v)].addr, v.unsafeAddr, sizeof(v))

func addUint64*(s: var string, v: uint64) {.inline.} =
  func addUint64Slow(s: var string, v: uint64) {.inline.} =
    s.add ((v and 0x00000000000000FF'u64) shr 0).char
    s.add ((v and 0x000000000000FF00'u64) shr 8).char
    s.add ((v and 0x0000000000FF0000'u64) shr 16).char
    s.add ((v and 0x00000000FF000000'u64) shr 24).char
    s.add ((v and 0x000000FF00000000'u64) shr 32).char
    s.add ((v and 0x0000FF0000000000'u64) shr 40).char
    s.add ((v and 0x00FF000000000000'u64) shr 48).char
    s.add ((v and 0xFF00000000000000'u64) shr 56).char

  when defined(nimscript):
    addUint64Slow(s, v)
  else:
    when nimvm:
      addUint64Slow(s, v)
    else:
      # Fast path for native
      s.setLen(s.len + sizeof(v))
      copyMem(s[s.len - sizeof(v)].addr, v.unsafeAddr, sizeof(v))

proc add*(buffer: var string, val: byte) {.inline.} =
  buffer.add(val.char)


proc addBe32*[T: Bit32Type](buffer: var string, val: T) {.inline.} =
  let swapped: uint32 = cast[uint32](swap(val))
  buffer.addUint32(swapped)

proc addBe64*[T: Bit64Type](buffer: var string, val: T) {.inline.} =
  let swapped: uint64 = cast[uint64](swap(val))
  buffer.addUint64(swapped)

proc readBe32*[T: Bit32Type](s: string, i: var int): T {.inline} =
  if i + 4 > s.len:
    raise newException(OscParseError, "Not enough bytes to read 32-bit number")
  proc readBe32Slow[T: Bit32Type](s: string, i: var int): T {.inline} =
    let tmp: uint32 = 
        (s[i].uint32 shl 0) or (s[i+1].uint32 shl 8) or (s[i+2].uint32 shl 16) or (s[i+3].uint32 shl 24)
    result = cast[T](tmp)

  var tmp: T
  when defined(nimscript):
    tmp = readBe32Slow[T](s, i)
  else:
    when nimvm:
      tmp = readBe32Slow[T](s, i)
    else:
      copyMem(tmp.addr, s[i].unsafeAddr, 4)

  result = swap(tmp)
  i += 4

proc readBe64*[T: Bit64Type](s: string, i: var int): T {.inline} =
  if i + 8 > s.len:
    raise newException(OscParseError, "Not enough bytes to read 64-bit number")
  proc readBe64Slow[T: Bit64Type](s: string, i: var int): T {.inline} =
    let tmpu: uint64 = 
      (s[i].uint64 shl 0) or (s[i+1].uint64 shl 8) or (s[i+2].uint64 shl 16) or (s[i+3].uint64 shl 24) or
      (s[i+4].uint64 shl 32) or (s[i+5].uint64 shl 40) or (s[i+6].uint64 shl 48) or (s[i+7].uint64 shl 56)
    result = cast[T](tmpu)

  var tmp: T
  when defined(nimscript):
    tmp = readBe64Slow[T](s, i)
  else:
    when nimvm:
      tmp = readBe64Slow[T](s, i)
    else:
      copyMem(tmp.addr, s[i].unsafeAddr, 8)

  result = swap(tmp)
  i += 8

