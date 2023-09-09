## noscat - Print OSC messages received on a given port
## Usage: noscsend ADDRESS PORT OSC_ADDRESS DATA

import std/net
import std/parseutils
import std/strutils
import nosc
import os

let pc = paramCount()
if pc < 2:
  echo "Usage: noscsend ADDRESS PORT [DATA]"
  quit(1)

let address = paramStr(1)
let port = Port(paramStr(2).parseInt())
let oscAddr = paramStr(3).strip()
let dataArgs = paramStr(4).strip()
if not oscAddr.startsWith("/"):
  stderr.writeLine("error: osc address should be an osc adress and start with /")
  quit(1)

let socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

# Parse dataArgs into a list of OscValues
var args: seq[OscValue] = @[]
for word in dataArgs.split(" "):
  if word[0].isDigit():
    try:
      let ival: int = parseInt(word)
      if ival <= int32.high and ival >= int32.low:
        args.add(%ival.int32)
      else:
        args.add(%ival)
    except ValueError:
      try:
        let fval: float32 = parseFloat(word)
        args.add(%fval)
      except ValueError:
        stderr.writeLine("error: could not parse " & word & " as a number")
        quit(1)
  else:
    args.add(%word)
    # TODO: Parse True/False/Nil, maybe also times?

let msg = OscMessage(address: oscAddr, params: args)
echo "Sending ", msg

socket.sendTo(address, port, msg.dgram())
