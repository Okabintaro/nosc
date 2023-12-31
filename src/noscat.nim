## noscat - Print OSC messages received on a given port
## Usage: noscat ADDRESS PORT [PREFIX]

## TODO/Ideas:
## - Handle Ctrl-C better
## - Error to stderr
## - Prettier output, json/csv output?
## - Make filter a regex or osc address pattern
## - Add option to print raw data/hex?

import std/net
import std/strformat
import std/strutils
import std/options
import nosc/hexprint
import nosc
import os

let pc = paramCount()
if pc < 2:
  echo "Usage: noscat ADDRESS PORT [PREFIX]"
  quit(1)

let address = paramStr(1)
let port = Port(paramStr(2).parseInt())
var prefix = none(string)
if pc >= 3:
  prefix = some(paramStr(3))
if prefix.isSome and not prefix.get.startsWith("/"):
  echo "error: prefix should be an osc adress and start with /"
  quit(1)


let socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
socket.bindAddr(port, address)
echo fmt"Listening on {address}:{port}, prefix: ""{prefix}""."

# For UDP 2048 should be enough?
# While you could go up to 65,535 it's not recommended. Most packets should be 500ish max
# See https://stackoverflow.com/q/109889 for a discussion on this.
const BUFSIZE = 2048
var data = newString(BUFSIZE)

var recvaddr = ""
var recv_port: Port
while true:
  let len = socket.recvFrom(data, BUFSIZE, recvaddr, recvport)
  discard len # Not really useful, data.len is set.

  proc processMessage(msg: OscMessage) =
    if prefix.isSome:
      if msg.address.startsWith(prefix.get):
        echo msg
    else:
      echo msg

  proc processPacket(pkt: OscPacket) =
    case pkt.kind:
      of oscMessage:
        processMessage(pkt.msg)
      of oscBundle:
        for pkt in pkt.bundle.contents:
          processPacket(pkt)

  try:
    let packet = readPacket(data)
    processPacket(packet)
  except OscParseError as e:
    echo "error parsing dgram: " & e.msg & "\ndata:"
    echo hexPrint(data)

