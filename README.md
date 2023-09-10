# nosc

[![Github Actions](https://github.com/Okabintaro/nosc/workflows/Github%20Actions/badge.svg)](https://github.com/Okabintaro/nosc/actions/workflows/build.yml)

[API reference](https://okabintaro.github.io/nosc/)

## About

A pure nim implementation of the [OSC(Open Sound Control) 1.0][OSC 1.0] protocol.

**NOTE:** Still Work in Progress. See [Tasks/WIP](#taskswip) section below.

## Features

- Parsing and writing of OSC messages
- Supports Nimscript and Compile-Time execution
- Reasonably well tested
  - Ported test cases from [python-osc][python-osc-tests]

## Tasks/WIP

This module is still work in progress and my first big nim project.
It needs some more work to be done, specifically parsing and writing of bundles and the matching of addresses.
Furthermore, I want to test it more, create python bindings and need to improve the documentation.

Take a look at [TODO.md](TODO.md) for a list of next steps.

## Attribution

- [Test cases][python-osc-tests] are ported from [python-osc][python-osc]
- `hexprint.nim` from [treeform/flatty][hexprint]
- `pretty.nim` from [treeform/pretty][pretty]
- `stream.nim` contains ideas and code from [treeform/flatty][flatty]
- `tests/benchy` from [treeform/benchy][benchy]

All of those are made by [treeform][treeform] and are licensed under the MIT license.
See the [LICENSE.treeform](src/nosc/LICENSE.treeform) file for the full license.

## License

This project is licensed under the MIT license.
See the [LICENSE](LICENSE) file for the full license.

[OSC 1.0]: https://opensoundcontrol.stanford.edu/spec-1_0.html
[python-osc]: https://github.com/attwad/python-osc
[python-osc-tests]: https://github.com/attwad/python-osc/blob/master/pythonosc/test
[hexprint]: https://github.com/treeform/flatty/blob/master/src/flatty/hexprint.nim
[pretty]: https://github.com/treeform/pretty
[flatty]: https://github.com/treeform/flatty
[benchy]: https://github.com/treeform/benchy
[treeform]: https://github.com/treeform
