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
    - [X] Simplify writer by using str.len
    - [X] Introduce procs for writing time and color
    - [X] Port/Copy needed functions and make sure they work in compile time
      - [X] swap32, swap64
      - [X] addUint32, addUint64
      - [X] readUint32, readUint64
      - [X] addByte, readByte
    - [X] Write some compile time tests

  - [O] Comparison/Oracle Test: Compare to python-osc
    - [X] Did some tests with python bindings and nimpy, quite easy to use
    - [X] Finish up basic bindings
    - [X] Learn and use hypothesis to generate random messages
      - [O] Create a random osc message
        - [X] Only tests 4 standard types, Create tests using all supported types
        - [ ] python support for all the types
        - [ ] Create new message strategy
      - [O] Equality Tests: Serialize with both implementations and compare buffer
      - [O] Test some other properties from the spec
        - [X] Message length is always a multiple of 4
      - [O] Encoder/Decoder Tests
        - [ ] Combination 1: Encode with nim, decode with python
        - [ ] Combination 2: Encode with python, decode with nim
        - [X] Combination 3: Encode with nim, decode with nim
        - [ ] Combination 4: Encode with python, decode with python
          - Might find bugs in python implementation too
    - [O] Fuzzing using [drchaos](https://github.com/status-im/nim-drchaos)
      - [X] Fuzz the parser
      - [ ] Try to generate actual messages instead of random bytes

- [O] Bundles
  - [X] Read the specs
  - [X] Implement bundle parsing and writing
  - [O] Port bundle tests from python-osc
  - [ ] Write proptest for bundles

- [ ] Integration Test?: Simple OSC Server <-> Client Based Test
- [ ] benchmarks: Count allocations if possible, to see if we can reduce them
- [ ] Cleanup/Style
  - [ ] message.params -> message.args: They are called arguments in the spec

- [ ] Improve Documentation
  - [ ] Learn nimdoc
  - [ ] Add runnable examples
  - [ ] Small Tutorial, some how-tos
    - Use [nimibook](https://github.com/pietroppeter/nimibook)?

### 0.2 Dispatcher + Performance

- [ ] Dispatcher

### Nice to have

- [ ] JS Support?
  - [ ] Refactor stream.nim from branch to use jsbinny/js procedures
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
