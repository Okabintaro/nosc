# Property tests for nosc/noscpy using hypothesis.

from typing import Any
from hypothesis import (
    given,
    note,
    settings,
)  # noqa: F401
import hypothesis.strategies as st
from pythonosc.osc_message_builder import OscMessageBuilder
from pythonosc.osc_message import OscMessage
import noscpy  # type: ignore


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
    # build_noscpy("\ud800", [])


class FakeOscMessage:
    def __init__(self, addres: str, args: list[Any]) -> None:
        self.address = addres
        self.args = args

    def __repr__(self) -> str:
        return "FakeOscMessage(" + repr(self.address) + ", " + repr(self.args) + ")"

    def dgram_pyosc(self) -> bytes:
        msg = OscMessageBuilder(self.address)
        for arg in self.args:
            msg.add_arg(arg)
        return msg.build().dgram

    def dgram_nosc(self) -> bytes:
        return noscpy.message(self.address, self.args).dgram()


# Inlcuding a null byte in the address causes problems
sensible_characters = st.characters(blacklist_characters="\x00", codec="utf-8")
sensible_text = st.text(alphabet=sensible_characters, min_size=1)

standard_osc_arguments = [
    st.integers(min_value=-2147483648, max_value=2147483647),
    st.floats(width=32, allow_nan=False, allow_infinity=False),
    st.binary(min_size=1),
    sensible_text,
]


extended_osc_arguments = standard_osc_arguments + [st.booleans()]
osc_message_values = st.lists(st.one_of(extended_osc_arguments))


@st.composite
def osc_message(draw, address=sensible_text, args=osc_message_values):
    address = "/" + draw(address)
    return FakeOscMessage(address, draw(args))


def check_eql(dgram1: bytes, dgram2: bytes, names: tuple[str, str] = ("pyosc", "nosc")):
    if dgram1 != dgram2:
        note(names[0] + ":\n" + str(hexdump(dgram1)))
        note(names[1] + ":\n" + str(hexdump(dgram2)))
        raise AssertionError("Datagrams not equal")


@settings(max_examples=1000)
@given(msg=osc_message())
def test_pythonosc_oracle(msg: FakeOscMessage):
    """Check if we produce the same datagram as python-osc."""
    dgram_pyosc = msg.dgram_pyosc()
    dgram_nosc = msg.dgram_nosc()
    check_eql(dgram_pyosc, dgram_nosc)


@settings(max_examples=1000)
@given(fake_msg=osc_message())
def test_nosc_enc_pyosc_dec(fake_msg: FakeOscMessage):
    """Check if we can decode nosc messages with python-osc."""
    dgram_nosc = fake_msg.dgram_nosc()
    msg = OscMessage(dgram_nosc)
    assert msg.address == fake_msg.address
    assert msg.params == fake_msg.args


@settings(max_examples=1000)
@given(fake_msg=osc_message())
def test_pyosc_enc_nosc_dec(fake_msg: FakeOscMessage):
    """Check if we can decode python-osc messages with nosc."""
    dgram_pyosc = fake_msg.dgram_pyosc()
    msg = parse_noscpy(dgram_pyosc)
    if isinstance(msg, str):
        note(str(hexdump(dgram_pyosc)))
        raise AssertionError(f"Unexpected error: {msg}")
    assert msg.address() == fake_msg.address
    assert msg.args() == fake_msg.args


@settings(max_examples=1000)
@given(fake_msg=osc_message())
def test_pyosc_enc_pyosc_dec(fake_msg: FakeOscMessage):
    """Test python-osc with itself."""
    dgram_pyosc = fake_msg.dgram_pyosc()
    msg = OscMessage(dgram_pyosc)
    assert msg.address == fake_msg.address
    assert msg.params == fake_msg.args


@settings(max_examples=1000)
@given(msg=osc_message())
def test_len_multiple_of_4(msg: FakeOscMessage):
    dgram_nosc = msg.dgram_nosc()
    if len(dgram_nosc) % 4 != 0:
        note(str(hexdump(dgram_nosc)))
        raise AssertionError(f"Length not multiple of 4, was {len(dgram_nosc)}")


@settings(max_examples=1000)
@given(fake_msg=osc_message())
def test_round_trip(fake_msg: FakeOscMessage):
    """Check if we can decode our own messages."""
    addr, args = fake_msg.address, fake_msg.args
    addr = "/" + addr
    msg = noscpy.message(addr, args)
    dgram = msg.dgram()
    msg2 = parse_noscpy(msg.dgram())
    if isinstance(msg2, str):
        note(str(hexdump(dgram)))
        raise AssertionError(f"Unexpected error: {fake_msg}")
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
    test_nosc_enc_pyosc_dec()
    test_pyosc_enc_nosc_dec()
    test_pyosc_enc_pyosc_dec()
    test_len_multiple_of_4()
    test_round_trip()
    test_fuzz()
