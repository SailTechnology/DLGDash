# Native Lua memory regression

Fengari verifies behavior, instruction counts and rendering, but does not model
the firmware's allocator. Use `memory-runner.c` with upstream Lua 5.2.4/5.3.6 for a
separate allocation regression. Build in a temporary or ignored output directory.

```sh
cc -O2 -I /path/to/lua-5.3.6/src memory-runner.c \
  /path/to/lua-5.3.6/src/liblua.a -lm -o /path/to/output/memory-runner
/path/to/output/memory-runner memory-spec.lua /path/to/DLGDash 240000 setup
/path/to/output/memory-runner memory-spec.lua /path/to/DLGDash 0 telemetry
```

The runner requires Lua headers and their matching static library. Download
upstream source from https://www.lua.org/ftp/lua-5.3.6.tar.gz and build `generic`.
The archive SHA-256 is
`fc5fd69bb8736323f026672b1b7235da613d7177e72558893a0bdcd320466d60`.
Do not put the compiler, library or compiled scripts in the radio package.

Also test Lua 5.2.4 (https://www.lua.org/ftp/lua-5.2.4.tar.gz), SHA-256
`b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b`.
Build another runner against that library. Use scenarios `legacy-setup` and
`legacy-telemetry` to remove the APIs unavailable on EdgeTX 2.7.1.

The scenario traverses every setting twice, selects the last value of every
picker, enables Chinese, saves, then reopens the tool and loads its profile.
It supplies 150 non-telemetry sources to expose retained source-list growth.
`setup` models a standalone tool; `telemetry` also keeps the dashboard loaded.

The optional limit is **desktop Lua allocation bytes**, not the Zorro's RAM
capacity. A zero limit measures the unconstrained peak. Results include standard
libraries and API stubs. Pointer size, number representation, parser/debug data,
allocator fragmentation and firmware read-only tables differ from EdgeTX.
Never report these numbers as measured radio memory or hardware acceptance.

For comparison on the same 64-bit Lua 5.3 build, published v1.0 fails the 240000
byte standalone scenario; the reduced-load development version passes it.
Separate real-radio checks remain required for cold source compilation, Chinese
menus, telemetry plus settings, saving, and coexistence with other Lua scripts.

The supplied Zorro failure video showed `not enough memory`; its subsequent
version photo showed EdgeTX 2.7.1. compat.lua supplies the verified legacy read
path, while the settings loader constructs only the active page and never
compiles the color renderer on monochrome. The standalone entry rejects missing
essential APIs before loading modules. test_mono.lua exercises both old/new
paths independently of these native tests. Actual radio acceptance is pending.
