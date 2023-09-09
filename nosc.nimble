version     = "0.1.0"
author      = "Okabintaro"
description = "Pure Nim implementation of the OSC(Open Sound Control) protocol"
license     = "MIT"

srcDir = "src"
bin    = @["noscat", "noscsend"]
installExt = @["nim"]

requires "nim >= 1.2.2", "nimpy"


