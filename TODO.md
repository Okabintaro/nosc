# TODO/Roadmap

## Core

- [O] Messages
  - [X] Port remaining unit tests from python-osc
  - [X] Test and implement remaining parsing for types
    - readTimeTag, float64, Inf, etc
    - [X] d: float64/double: 64 bit (“double”) IEEE 754 floating point number
    - [X] I: Infinitum. No bytes are allocated in the argument data.
    - [X] c: an ascii character, sent as 32 bits
    - [X] r: 32 bit RGBA color
    - [X] m: 4 byte MIDI message. Bytes from MSB to LSB are: port id, status byte, data1, data2
  - [X] Cleanup tests using comparison operator
  - [X] Implement basic serialization
  - [X] Add some benchmarks with benchy
  - [X] Investigate/Commit writeTags optimization
  - [X] Compile / NimScript support
  - [X] (Maybe) JS Support?
    - [O] Test if NimScript support implies JS support
      - There are issues with float/double mainly
  - [O] Comparison/Oracle Test: Compare to python-osc
    - [X] Did some tests with python bindings and nimpy, quite easy to use
    - [ ] Learn and use hypothesis to generate random messages
      - [ ] Equality Tests: Serialize with both implementations and compare buffer
      - [ ] Encoder/Decoder Tests
        - [ ] Combination 1: Encode with nim, decode with python
        - [ ] Combination 2: Encode with python, decode with nim
        - [ ] Combination 3: Encode with nim, decode with nim
        - [ ] Combination 4: Encode with python, decode with python
          - Might find bugs in python implementation too
    - [ ] Maybe also try to generate random messages in nim
  - [ ] Integration Test: Simple OSC Server <-> Client Based Test
  - [ ] benchmarks: Count allocations if possible, to see if we can reduce them

- [ ] Bundles
- [ ] Matching
- [ ] Cleanup/Style
  - [ ] proc -> func if possible
  - [ ] Remove echo warning
  - [ ] message.params -> message.args: They are called arguments in the spec

- [ ] Improve Documentation
  - [ ] Learn nimdoc
  - [ ] Add runnable examples

### Nice to have

- [ ] Create nimib with report/explanations
- [ ] Test JS build?
- [ ] Interactive Web based builder for an explanation of the OSC Protocl

## Tools

Write some cli tools for osc as a demonstration.

- [ ] noscsend
  - Simply send a osc message to a given address
  - Usage: `noscsend <ip:port> <address> <values>`
    - Example: `noscsend localhost:1234 /test 1`
- [O] noscat
  - [X] Print all messages/bundles by listening to a port
  - [ ] Add filter by address
- [ ] nosctop(maybe)
  - [ ] Interactive TUI to show all messages/bundles
  - [ ] Filter by address, like in htop
  - [ ] Plot values over time?
