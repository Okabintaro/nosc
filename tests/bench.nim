import benchy
import nosc

timeIt "parse message":
  const DGRAM_ALL_NON_STANDARD_TYPES_OF_PARAMS =
      "/SYNC\x00\x00\x00" &
      "T" &  # True
      "F" &  # False
      "N" &  # Nil
      "[]th\x00" &  # Empty array
      "\x00\x00\x00\x00\x00\x00\x00\x00" &
      "\x00\x00\x00\xe8\xd4\xa5\x10\x00" # 1000000000000
  let msg = parseMessage(DGRAM_ALL_NON_STANDARD_TYPES_OF_PARAMS)
  keep msg

timeIt "serialize message":
    let msg = OscMessage(
        address: "/test",
        params: @[%true, %false, %[%1, %2, %"no"], %"Hello World"]
    )
    let dg = msg.dgram()
    keep dg
