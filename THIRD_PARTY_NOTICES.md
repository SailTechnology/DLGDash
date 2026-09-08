# Third-Party Notices

DLGDash author: Sail.

## Chinese UI Bitmaps

The generated PNG and BMP labels under `scripts/edgetx/DLGDash/lang` use Noto Sans SC. The font is licensed under the SIL Open Font License 1.1. The complete notice is distributed as `lang/OFL.txt` in the source and installation package.

Font project: https://github.com/notofonts/noto-cjk

## EdgeTX Test References

The test runner downloads selected font assets from the official EdgeTX v2.11.3 source tree. Their source paths and SHA-256 hashes are pinned in `tests/reference-fonts.json`. Downloaded files remain in the ignored `tests/reference` cache and are not redistributed in this repository or the installation ZIP.

V12 tests additionally use the small-display fonts from official EdgeTX commit `92c3224699b545a47acaf8bd301b0ab4f2b91848`, which introduced the current V12 target. These references are pinned by commit and SHA-256 in the same manifest and follow the same test-only distribution rules.

EdgeTX source and licensing: https://github.com/EdgeTX/edgetx/tree/v2.11.3

The displayed test screenshots use those firmware fonts. They are generated diagnostic renders with synthetic flight data, not manufacturer certification or real hardware photographs. EdgeTX, RadioMaster, FrSky and HelloRadio names identify compatibility targets only; no endorsement is implied.

## Development Dependencies

Fengari, pngjs and lz4js are development-only dependencies retrieved through the package manager. Their versions are pinned in the lockfile; their own licenses apply. The optional Chinese asset generator uses @napi-rs/canvas. No Node dependency is installed on the radio.

## Original Code

No separate open-source license for DLGDash's original code has been selected for this first public release. Third-party license notices do not change ownership or licensing of the original code.
