# Font sources

## Jersey 10

- Runtime file: `App/Resources/Fonts/jersey-10-regular.ttf`
- Retained source: `assets/fonts/sources/jersey-10-regular.ttf`
- Family and weight: Jersey 10 Regular, 400
- Source: Google Fonts repository, `ofl/jersey10/Jersey10-Regular.ttf`
- Upstream: https://github.com/google/fonts/tree/main/ofl/jersey10
- Original project: https://github.com/scfried/soft-type-jersey at source commit `d8446c4c9c2ba14cf408c295be35213c006e19ff`
- Licence: SIL Open Font License 1.1; retained as `assets/fonts/OFL-Jersey10.txt`
- Local treatment: the reviewed binary is unmodified; the stable lowercase runtime filename differs from the upstream filename
- Font SHA-256: `db9cbd091617048a145d249daa2b815fe7083be6ab66ac26626e21a4e01c3e82`
- Retained licence SHA-256: `0b700740d19d2817b5db90f0451d6f19a6cc9dd94a251b53abb52fefced4a97f`
- Migration source: copied byte-for-byte from parent web repository commit `923a38e` on 2026-07-16
- First shipped build: not shipped; internal alpha 0.1.0 (1) candidate only

The Pixel theme uses this font for display copy while retaining Dynamic Type scaling. Google Fonts lists Latin and Latin Extended coverage; unsupported characters fall back to the system font. Runtime and retained copies, the licence, `Info.plist` registration, and hashes are checked by `Scripts/validate-assets.sh`.
