from typing import Any
import noscpy
from pythonosc.osc_message_builder import OscMessageBuilder
import math


def build(address: str, args: list[Any]) -> bytes:
    msg = OscMessageBuilder(address)
    for arg in args:
        msg.add_arg(arg)
    return msg.build().dgram


dgram_noscpy = noscpy.build("/Shit", [math.nan]).dgram()
dgram_pyosc = build("/Shit", [math.nan])
print(dgram_noscpy)
print(dgram_pyosc)

parsed_msg = noscpy.parse(dgram_noscpy)
print(parsed_msg.str())
