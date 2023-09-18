from typing import Any

class NimPyException(Exception): ...

OscValue = int | float | str

class OscMessage:
    """An OSC message, created by nosc.

    NOTE: There is no constructor/__init__ for this type.
    Use `parse` to create one from a datagram or `message` to create one from scratch.
    """

    @classmethod
    def __init__(cls, *args, **kwargs) -> None:
        """Creates an empty message. Not really useful.

        See `message` for a more useful constructor.
        """
    def arg(self, index: int) -> OscValue:
        """Get the i-th argument of the OSC message.

        Limited to int32, float32 and string for now.
        """
    def address(self) -> str:
        """Get the address of the OSC message."""
    def args(self) -> list[OscValue]:
        """Get all the arguments of the OSC message."""
    def dgram(self) -> bytes:
        """Returns the OSC message as a datagram."""
    def str(self) -> str:
        """Return a string representation of the OSC message."""
    def hexprint(self) -> str:
        """Return a hex pretty-print of the OSC message."""
    def __get__(self, instance, owner) -> Any:
        """Not sure what this does."""

def message(address: str, args: list[Any]) -> OscMessage:
    """Create an OSC message from scratch."""

def parse(buffer: str | bytes) -> OscMessage:
    """Parse an OSC datagram into an OscMessage."""
