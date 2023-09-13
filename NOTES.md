# Notes

Some notes about experiments I tried.

## CI/CD

Ideal CI/CD Setup:

This is my ideal nim CI/CD setup, I am not sure how much of this is possible.

- Cross-Compile tests and applications on all platforms
- Run tests on all platforms
- Compile and run all tests with clang sanitizers and checks
- Create binaries for all platforms and create a release/nightly for each commit?
  - Maybe just create a release for a tagged commit
  - Use git-cliff to generate changelog
- Measure binary size with bloaty
- Report allocations/heap usage with valgrind
- Report code coverage?
- Run benchmarks using callgrind and benchy?
  - Not sure how good CI/CD is for this
- Create a docker/prebuilt container with all the tools for speed

## Allocations

I compiled the tests using special flags and `` and could use valgrind to measure the allocations.

  nim c --mm:arc --threads:off -d:useMalloc --opt:size test.nim
  valgrind --tool=massif ./test
  ms_print massif.out.96232 >heapallocs.txt

This gives a nice report of the allocations.
Currently the parseUntil function allocates for each invocation into the return/result value.
I wonder how bad this is with the nim allocator and how you would avoid it best.
There is the experimetnal view feature of nim, but I am not sure if it is worth it or if there is another way.
I should look at other nim libraries and think about the API maybe too.

## Cross-Compiling using Zig

I used [zigcc](https://github.com/enthus1ast/zigcc) to make a nice, small executable for linux:

```bash
nim c --cc:clang --clang.exe="zigcc" --clang.linkerexe="zigcc" --passL:"-target x86_64-linux-musl" --forceBuild:on  --passC:-flto --passL:-flto --passL:-static --passL:-Wl,-dead_strip --mm:arc -d:release --opt:speed -d:useMalloc noscat.nim
```

- [X] Use zig-cc to cross compile
  - [X] To windows
  - [X] To macos
- [O] Integrate in nimble
- [ ] Make github action to build binaries for all platforms and create a release

## Tooling/Misc

- I want a nice hexdump macro/function for the protocol world
  - It was [flatty/hexprint](https://github.com/treeform/flatty/blob/master/src/flatty/hexprint.nim)!

### Planned features/readme

```md
## Features

- Well tested
  - Ported test cases from [python-osc][python-osc-tests]
  - Comparison/Oracle Tests against [python-osc][python-osc]
  - Fuzzed
- Fast
- Compatible with nimscript and javascript
  - This means you can construct and parse messages at compile time too
```

## nimpy experiments

I find [nimpy][nimpy] to be a very interesting package and really smart use of nims macro system.
Initially I wanted to just make simple bindings for property testing nosc against python-osc, but I think
you could also make proper bindings for nosc using nimpy.

There are a couple of things I would be missing though or would have to take another approach for it.

### Type hints

It would be nice if the exported packages would have type hints and nice documentation,
directly derived from the nim.

I tried to make a quick and dirty macro as an exercise, which works but having full coverage of all possible
types and combinations would be a lot of work. I am not sure if it would be worth it entirely.

You can already use [stubgen](https://mypy.readthedocs.io/en/stable/stubgen.html#stubgen) from mypy to create a stub that you could doucment then:

```bash
$ ls noscpy.so # noscpy.so must be in the same directory
noscpy.so*
$ stubgen -m noscpy
Processed 1 modules
Generated out/noscpy.pyi
```

which generates a stubfile called `out/noscpy` like this:

```python
from typing import Any

class NimPyException(Exception): ...

class OscMessage:
    @classmethod
    def __init__(cls, *args, **kwargs) -> None: ...
    def arg(self, *args, **kwargs) -> Any: ...
    def dgram(self, *args, **kwargs) -> Any: ...
    def init(self, *args, **kwargs) -> Any: ...
    def __get__(self, instance, owner) -> Any: ...

def build(*args, **kwargs) -> Any: ...
def parse(*args, **kwargs) -> Any: ...
```

In my case where I build a small api it is not as much work adding all the types
and documentation comments, but it could be nice generating those for all the
supported nim types automatically.

### More pytype stuff

I wonder how hard it would be to add support for `__init__` and other python magic methods to nimpy.

I looked briefly into it and it would need some more macro magic I think.
For all the special `__magic__` there exists a function pointer in the `PyTypeObject` struct:

```nim
  PyTypeObject3* = ptr PyTypeObject3Obj
  PyTypeObject3Obj* = object of PyObjectVarHeadObj
    tp_name*: cstring
    tp_basicsize*, tp_itemsize*: Py_ssize_t

    # Methods to implement standard operations
    tp_dealloc*: Destructor
    tp_print*: Printfunc

    tp_getattr*: Getattrfunc
    tp_setattr*: Setattrfunc

    ...

    tp_init*: Initproc
```

In this case for `__init__` it would be `tp_init*`.
It is also documented in the [python docs](https://docs.python.org/3/c-api/typeobj.html).

One of those is also [`tp_init*`](https://docs.python.org/3/c-api/typeobj.html#c.PyTypeObject.tp_init).
For nimpy to fill this struct, you need to modify [`PyTypeDesc`](https://github.com/yglukhov/nimpy/blob/c21c0812e7e535f363664dfa684e5e79ad448faf/nimpy.nim#L38-L45) which gets parsed by the macros and then used to fill the actual PyTypeObject struct.

### Buffer protocol

Additionally for serialization and also for parsing it would be nice to have more access to the buffer protocol.
Initially I thought that we might need the buffer protocol for [`tp`](https://docs.python.org/3/c-api/typeobj.html#c.PyTypeObject.tp_as_buffer) but I am actually not sure if we need it.
As soon as you serialize the message it can easily be owned by python.

[nimpy]: https://github.com/yglukhov/nimpy
