# DLGDash Development

This file is not included in the radio installation package. User instructions
are in INSTALL-BEGINNER.md and scripts/edgetx/DLGDash/README.md.

## Runtime and data boundaries

The widget and telemetry entry share read-only model/source logic. Settings are
keyed by radio plus model filename; there is no fallback to a non-unique display
name. DLG2/3/4 profiles migrate in memory to schema 5. Two alternating checksummed
slots and readback protect saves. Never distribute model/radio files, profiles,
diagnostic records, credentials or compiler-generated luac files.

Profile save paths must exist on old firmware without mkdir. The package and
installer create empty profiles and diagnostics directories. Installation checks
a fresh backup and verifies original MODELS, RADIO and profile hashes afterward.

The top-right author label remains part of the UI; full-screen color mode uses
SET as its settings command. This is intentionally not described in the user
tutorial beyond explaining how to open settings.

## Compatibility

compat.lua does not replace firmware globals. Prefer getSourceValue and
getOutputValue when present. The EdgeTX 2.7.1 fallback uses getValue, getFieldInfo
and getRSSI. Its getValue channel values are ex_chans BEFORE limits/reversal;
the dashboard labels this MIX. Do not approximate the firmware's output engine.

Old firmware cannot expose individual sensor expiry/freshness. Link loss hides
telemetry and stops tones, but sensor-only staleness cannot be certified. Do not
infer packet arrival or loss from an unchanged value. Tone volume falls back to
the radio setting when per-tone volume is unavailable. Old color firmware without
bitmap masks falls back to English; monochrome Chinese uses BMPs.

Reference implementations:

- https://github.com/EdgeTX/edgetx/blob/v2.7.1/radio/src/lua/api_general.cpp
- https://github.com/EdgeTX/edgetx/blob/v2.7.1/radio/src/lua/api_model.cpp
- https://github.com/EdgeTX/edgetx/blob/v2.7.1/radio/src/mixer.cpp
- https://github.com/EdgeTX/edgetx/blob/v2.11.3/radio/src/lua/api_general.cpp
- https://github.com/EdgeTX/edgetx/blob/v2.11.3/radio/src/gui/navigation/navigation.h

## Tests and packaging

From scripts/edgetx/DLGDash/tests, run pnpm install --frozen-lockfile and pnpm test.
The tests cover PA01/V16, X9D/GX12/Zorro monochrome, legacy Zorro API behavior,
Chinese/English layout, sources, launch, outputs, audio and profile round trips.
Fengari does not implement Lua garbage collection; that call is explicitly
stubbed in the renderer and tested separately with native Lua 5.2/5.3.

Reference fonts are pinned to EdgeTX 2.11.3 and hash-verified. Renders enforce
bounds, text separation and fixed-width monochrome sentinel decoding. They are
not a complete EdgeTX simulator or proof of on-device memory/audio/key behavior.
Native heap regression instructions are in scripts/edgetx/DLGDash/tests/MEMORY.md.

The Zorro beta.1 retest reached the dashboard and servo page, then failed in
settings.lua's event lookup because the firmware did not expose _G. Settings now
compare direct event constants, with nil guards for optional events. Monochrome
and native memory tests remove _G before loading runtime modules. Keep this
environment regression separate from the earlier memory exhaustion report.

Build-Package.ps1 -Target Zorro creates a dedicated monochrome package from the
same core. It omits color modules/assets and includes only the Zorro user guide
and previews. This reduces the download, not a claim of new runtime heap savings.
tests/package-smoke.ps1 extracts the ZIP and runs the Zorro tests from those
installed paths, without falling back to unpackaged runtime files.

Build-Package.ps1 builds a clean SD ZIP and verifies every file hash. Run
tests/install-smoke.ps1 with PowerShell 7 for generated-card installation tests.
No real radio should be modified by these tests. Real cold compilation, mixed
Lua workloads, key events and telemetry loss must still be checked on hardware.

Original-code licensing has not been separately specified. Font licensing and
third-party attribution remain in THIRD_PARTY_NOTICES.md and the bundled OFL.
