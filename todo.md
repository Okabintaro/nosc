# TODO/Roadmap

## Core

- [O] Messages
  - [O] Port remaining unit tests from python-osc
  - [ ] Implement remaining parsing for types
  - [ ] Implement basic serialization
    - Allocation free possible?
    - Should just write to a buffer using parameters like printf/tinyosc
  - [ ] Integration test: Simple OSC Server <-> Client Based Test
  - [ ] Comparison/Oracle Test: Compare to python-osc
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
