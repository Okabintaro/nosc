import noscpy

# Create a new message with the address "/test/string" and a few arguments.
msg = noscpy.message("/test/string", [1, "Hello World", 1.23, False, True, b"Hello"])
# Acceess the arguments by their index.
print(msg.str())
assert msg.arg(0) == 1
assert msg.arg(1) == "Hello World"
f = msg.arg(2)
assert isinstance(f, float)
assert abs(f - 1.23) < 0.0001
assert msg.arg(3) is False
assert msg.arg(4) is True
assert msg.arg(5) == b"Hello"

# Serialize the message into a datagram and back again.
msg_dgram = msg.dgram()
msg2 = noscpy.parse(msg_dgram)
assert msg.str() == msg2.str()
assert msg.hexprint() == msg2.hexprint()
assert msg.dgram() == msg2.dgram()

# Print the messages values.
print(msg.str())
print(msg.hexprint())

# Error handling/exceptions
try:
    noscpy.parse("asdasd")
except noscpy.NimPyException as e:
    print("Expected error:")
    print(e)
