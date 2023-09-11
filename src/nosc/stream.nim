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

type Bit32Type = int32 | uint32 | float32
type Bit64Type = int64 | uint64 | float64


when system.cpuEndian == littleEndian:
  func swap*(v: uint16): uint16 {.inline.} =
    let tmp = cast[array[2, uint8]](v)
    (tmp[0].uint16 shl 8) or tmp[1].uint16

  func swap*(v: uint32): uint32 {.inline.} =
    func fallback(v: uint32): uint32 {.inline.} =
      ((v and (0xFF.uint32 shl 0)) shl 24) +
      ((v and (0xFF.uint32 shl 8)) shl 8) +
      ((v and (0xFF.uint32 shl 16)) shr 8) +
      ((v and (0xFF.uint32 shl 24)) shr 24)

    when defined(nimscript) or defined(js):
      return fallback(v)
    else:
      when nimvm:
        fallback(v)
      else:
        let tmp = cast[array[2, uint16]](v)
        (swap(tmp[0]).uint32 shl 16) or swap(tmp[1])

  func swap*(v: uint64): uint64 {.inline.} =
    func fallback(v: uint64): uint64 {.inline.} =
      ((v and (0xFF.uint64 shl 0)) shl 56) +
      ((v and (0xFF.uint64 shl 8)) shl 40) +
      ((v and (0xFF.uint64 shl 16)) shl 24) +
      ((v and (0xFF.uint64 shl 24)) shl 8) +
      ((v and (0xFF.uint64 shl 32)) shr 8) +
      ((v and (0xFF.uint64 shl 40)) shr 24) +
      ((v and (0xFF.uint64 shl 48)) shr 40) +
      ((v and (0xFF.uint64 shl 56)) shr 56)
    when defined(nimscript) or defined(js):
      return fallback(v)
    else:
      when nimvm:
        fallback(v)
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

  when defined(nimscript) or defined(js):
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

  when defined(nimscript) or defined(js):
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


func addFloat64BEJs(s: var string, v: float64) {.inline.} =
  {.emit: """
    var float64Array = new Float64Array(1);
    float64Array[0] = `v`;
    var uintArray = new Uint8Array(float64Array.buffer);
    for(var j = 0; j < 8; j++){
      `s`.push(uintArray[7-j]);
    }
  """.}


proc addBe64*[T: Bit64Type](buffer: var string, val: T) {.inline.} =
  when defined(js) and typeof(val) is float64:
    addFloat64BEJs(buffer, val)
  else:
    let swapped: uint64 = cast[uint64](swap(val))
    buffer.addUint64(swapped)

proc readBe32*[T: Bit32Type](s: string, i: var int): T {.inline} =
  proc readBe32Slow[T: Bit32Type](s: string, i: var int): T {.inline} =
    let tmp: uint32 = 
        (s[i].uint32 shl 0) + (s[i+1].uint32 shl 8) + (s[i+2].uint32 shl 16) + (s[i+3].uint32 shl 24)
    result = cast[T](tmp)

  var tmp: T
  when defined(nimscript) or defined(js):
    tmp = readBe32Slow[T](s, i)
  else:
    when nimvm:
      tmp = readBe32Slow[T](s, i)
    else:
      copyMem(tmp.addr, s[i].unsafeAddr, 4)

  result = swap(tmp)
  i += 4

func readFloat64BE*(s: string, i: int): float64 {.inline.} =
    {.emit: """
    var uintArray = new Uint8Array(8);
    for(var j = 0; j < 8; j++){
      uintArray[7-j] = `s`[`i` + j];
    }
    var float64Array = new Float64Array(uintArray.buffer);
    return float64Array[0];
  """.}

func readInt64BE*(s: string, i: int): int64 {.inline.} =
    {.emit: """
    var uintArray = new Uint8Array(8);
    for(var j = 0; j < 8; j++){
      uintArray[7-j] = `s`[`i` + j];
    }
    var uint64Array = new BigInt64Array(uintArray.buffer);
    return Number(uint64Array[0]);
  """.}


proc readBe64*[T: Bit64Type](s: string, i: var int): T {.inline} =
  proc readBe64Slow[T: Bit64Type](s: string, i: var int): T {.inline} =
    let tmpu: uint64 = 
      (s[i].uint64 shl 0) or (s[i+1].uint64 shl 8) or (s[i+2].uint64 shl 16) or (s[i+3].uint64 shl 24) or
      (s[i+4].uint64 shl 32) or (s[i+5].uint64 shl 40) or (s[i+6].uint64 shl 48) or (s[i+7].uint64 shl 56)
    result = cast[T](tmpu)

  when defined(js):
    when type(T) is float64:
      result = readFloat64BE(s, i)
    else:
      result = readInt64BE(s, i)
    i += 8
  else:
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

