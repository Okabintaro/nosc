# Property tests for nosc/noscpy using hypothesis.

from typing import Any
from hypothesis import (
    assume,
    given,
    note,
    settings,
)  # noqa: F401
import hypothesis.strategies as st
from pythonosc.osc_message_builder import OscMessageBuilder
import noscpy


# Taken from https://gist.github.com/NeatMonster/c06c61ba4114a2b31418a364341c26c0
# License: MIT
class hexdump:
    def __init__(self, buf, off=0):
        self.buf = buf
        self.off = off

    def __iter__(self):
        last_bs, last_line = None, None
        for i in range(0, len(self.buf), 16):
            bs = bytearray(self.buf[i : i + 16])
            line = "{:08x}  {:23}  {:23}  |{:16}|".format(
                self.off + i,
                " ".join(("{:02x}".format(x) for x in bs[:8])),
                " ".join(("{:02x}".format(x) for x in bs[8:])),
                "".join((chr(x) if 32 <= x < 127 else "." for x in bs)),
            )
            if bs == last_bs:
                line = "*"
            if bs != last_bs or line != last_line:
                yield line
            last_bs, last_line = bs, line
        yield "{:08x}".format(self.off + len(self.buf))

    def __str__(self):
        return "\n".join(self)

    def __repr__(self):
        return "\n".join(self)


def build_pyosc(address: str, args: list[Any]) -> bytes:
    msg = OscMessageBuilder(address)
    for arg in args:
        msg.add_arg(arg)
    return msg.build().dgram


def build_noscpy(address: str, args: list[Any]) -> bytes:
    return noscpy.message(address, args).dgram()


def python_osc_bug():
    # This makes the string not unicode for python-osc?
    msg = OscMessageBuilder("0")
    bad_string = "\x00𐀀"
    msg.add_arg(bad_string)
    msg.build()


def surrogates_noscpy():
    # This makes the string not unicode for nosc, surrogates.
    # But it's not a bug?
    print("\ud800")
    build_noscpy("\ud800", [])


# printable_characters = st.characters(whitelist_categories=("Ll", "Lu", "Nd", "Pc"))

# Inlcuding a null byte in the address causes problems
sensible_characters = st.characters(blacklist_characters="\x00", codec="utf-8")
sensible_text = st.text(alphabet=sensible_characters, min_size=1)

standard_osc_arguments = st.one_of(
    st.integers(min_value=-2147483648, max_value=2147483647),
    st.floats(width=32, allow_nan=False, allow_infinity=False),
    st.booleans(),
    st.binary(min_size=1),
    sensible_text,
)
osc_message_values = st.lists(standard_osc_arguments)


@settings(max_examples=1000)
@given(addr=sensible_text, args=osc_message_values)
def test_pythonosc_oracle(addr: str, args: list[Any]):
    """Check if we produce the same datagram as python-osc."""
    assume("\x00" not in addr)
    dgram_pyosc = build_pyosc(addr, args)
    dgram_nosc = build_noscpy(addr, args)
    if dgram_nosc != dgram_pyosc:
        note("PyOSC")
        note(str(hexdump(dgram_pyosc)))
        note("nosc")
        note(str(hexdump(dgram_nosc)))
        assert dgram_nosc == dgram_pyosc


@settings(max_examples=1000)
@given(addr=sensible_text, args=osc_message_values)
def test_len_multiple_of_4(addr: str, args: list[Any]):
    assume("\x00" not in addr)
    dgram_nosc = build_noscpy(addr, args)
    if len(dgram_nosc) % 4 != 0:
        note(str(hexdump(dgram_nosc)))
        raise AssertionError(f"Length not multiple of 4, was {len(dgram_nosc)}")


@settings(max_examples=1000)
@given(addr=sensible_text, args=osc_message_values)
def test_round_trip(addr: str, args: list[Any]):
    """Check if we can decode our own messages."""
    assume("\x00" not in addr)
    addr = "/" + addr
    msg = noscpy.message(addr, args)
    dgram = msg.dgram()
    msg2 = parse_noscpy(msg.dgram())
    if isinstance(msg2, str):
        note(str(hexdump(dgram)))
        raise AssertionError(f"Unexpected error: {msg}")
    assert msg.str() == msg2.str()


def parse_noscpy(data: bytes) -> noscpy.OscMessage | str:
    """Parse a datagram with nosc, return the message or an error message."""
    try:
        return noscpy.parse(data)
    except noscpy.NimPyException as e:
        return f"{e.__class__.__name__}: {str(e)}"


@settings(
    max_examples=1000,
    deadline=None,
)
@given(dgram=st.binary(min_size=1))
def test_fuzz(dgram: bytes):
    """Try to feed garbage to nosc. Hope it doesn't crash."""
    msg = parse_noscpy(dgram)
    if isinstance(msg, str):
        if not msg.startswith("OscParseError"):
            note(msg)
            note(str(hexdump(dgram)))
            raise AssertionError(f"Unexpected error: {msg}")
        assert "OscParseError" in repr(msg), f"{msg} is not an OscParseError"


if __name__ == "__main__":
    test_pythonosc_oracle()
    test_len_multiple_of_4()
    test_round_trip()
    test_fuzz()
