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

- [ ] Use zig-cc to cross compile
  - [ ] To windows
  - [ ] To macos
- [ ] Integrate in nimble
- [ ] Make github action to build binaries for all platforms and create a release

## Tooling/Misc

- I want a nice hexdump macro/function for the protocol world
  - It was [flatty/heyprint](https://github.com/treeform/flatty/blob/master/src/flatty/hexprint.nim)!

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

### Trying to understand the padding

```nim
when isMainModule:
  for i in 1..7:
    var buf: string = newStringOfCap(512)
    var values: seq[OscValue] =  @[]
    for j in 1..i:
      values.add(%j)
    let len = writeTagsString(buf, values)
    assert len %% 4 == 0
    print(i, len, values)
    echo hexPrint(buf)
    
    let msg = OscMessage(address: "/test", params: values)
    print msg
    echo hexPrint(msg.dgram())
```
