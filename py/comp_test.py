from typing import Any
from hypothesis import assume, given
from hypothesis.strategies import floats, text
from pythonosc.osc_message_builder import OscMessageBuilder
import math
import noscpy


def build_pyosc(address: str, args: list[Any]) -> bytes:
    msg = OscMessageBuilder(address)
    for arg in args:
        msg.add_arg(arg)
    return msg.build().dgram


def build_noscpy(address: str, args: list[Any]) -> bytes:
    return noscpy.build(address, args).dgram()


@given(addr=text(min_size=1), value=floats(width=32))
def test_same_encoding(addr: str, value: float):
    assume("\x00" not in addr)
    assume(not math.isnan(value))
    dgram_pyosc = build_pyosc(addr, [value])
    dgram_nosc = build_noscpy(addr, [value])
    if dgram_nosc != dgram_pyosc:
        print(dgram_pyosc, " != ", dgram_nosc)
        assert dgram_nosc == dgram_pyosc


test_same_encoding()

# def encode_float(f: float) -> bytes:
#     msg = OscMessageBuilder("/SYNC")
#     msg.add_arg(f, "f")
#     return msg.build().dgram


# def decode_float(s: bytes) -> float:
#     msg = noscpy.parse(s)
#     v = msg.arg(0)["floatVal"]
#     return v


# @given(floats(width=32))
# def test_decode_inverts_encode(f):
#     assume(not math.isnan(f))
#     assert decode_float(encode_float(f)) == f


# test_decode_inverts_encode()
