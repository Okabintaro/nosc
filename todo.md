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
  - [ ] Implement basic serialization
    - Allocation free possible?
      - For constant messsages we should be able to just construct the buffer at compile time.
    - Should just write to a buffer using parameters like printf/tinyosc
  - [ ] Integration test: Simple OSC Server <-> Client Based Test

  - [ ] Comparison/Oracle Test: Compare to python-osc
    - [ ] Not sure how yet, hypothesis + python or call python from nim?
  - [ ] Introduce Benchmarks?
    - [ ] Count allocations if possible, to see if we can reduce them
- [ ] Bundles
- [ ] Matching

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
