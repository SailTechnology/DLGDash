# EdgeTX VM Regression

The JavaScript renderer uses Fengari (Lua 5.3 semantics); upstream Lua 5.2.4
also does not reproduce EdgeTX v2.10.1's modified VM behavior. This optional
native harness builds the unmodified interpreter sources from official
EdgeTX tag `v2.10.1`, commit `839b60f6cc88d22383a6f686862b3fba4108884e`.

Use Linux/WSL, GCC and Bash. Point the build at an existing checkout:

```bash
bash tests/edgetx-vm/build.sh /path/to/edgetx/radio/src/thirdparty/Lua/src /absolute/path/edgetx-vm
/absolute/path/edgetx-vm tests/edgetx-vm/draw.lua /absolute/path/DLGDash
/absolute/path/edgetx-vm test_v16.lua /absolute/path/DLGDash
/absolute/path/edgetx-vm test_mono.lua /absolute/path/DLGDash
```

`draw.lua` sweeps 64 Lua call depths with an allocator that moves resized
blocks. The released beta.2 draw module fails at line 17 with `number expected,
got function`; beta.3 passes 10,000 rectangle/text/line cycles (30,000 native
draw calls). The minimal cause is `return math.floor(...)` followed by a C API
call after stack growth. EdgeTX's `OP_TAILCALL` falls through to `OP_RETURN`
without refreshing the stack pointer. Parenthesizing the single return value
prevents the C tail call. Other single-result C tail calls in runtime modules
are guarded too; no firmware globals or firmware files are modified.

The second command runs the V16 settings/navigation suite under this VM with
2.10 version capabilities, strict C drawing arguments, forced-moving allocations
and the project's in-memory radio/SD fixtures. It includes no-telemetry source
selection, a 3-minute widget idle simulation, a non-interactive refresh at 45s,
draft retention, explicit discard, a 90-second standalone idle and model change.
The injected 45-second interruption is a regression scenario, not proof that
the user's firmware has a 45-second timer.

This is a 64-bit host interpreter test. It does not emulate ARM RAM capacity,
LVGL focus, actual RF telemetry, firmware scheduling, fonts or the private V16
`403bdda7` selfbuild. Bitmap calls fall back to English here. Use `pnpm test`
for real-font PNG bounds checks and the upstream native memory harness for
allocation regression; all still require hardware ground acceptance.

The monochrome command uses T14 / 128x64 / EdgeTX 2.10 API fixtures. It traverses
both dashboard pages, all Chinese/English settings and pickers, saving and model
changes. Its C stubs check numeric drawing coordinates and bitmap paths, not
actual bitmap pixels. `node tests/run-mono.cjs --t14` separately checks those
pixels with reference fonts, including fixed-width spacing and screen bounds.

The harness replaces library initialization and radio C APIs only. ROM-backed
math/string libraries and the parser/VM/GC are the official sources. The optional
table library is deliberately not registered, matching the T14 save failure.
Compiler sources and host binaries are never included in SD installation ZIPs.
