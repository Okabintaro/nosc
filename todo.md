# TODO/Roadmap

## Core

- [O] Messages
  - [X] Port remaining unit tests from python-osc
  - [O] Implement remaining parsing for types
    - readTimeTag, float64, Inf, etc
  - [ ] Cleanup tests using comparison operator
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
