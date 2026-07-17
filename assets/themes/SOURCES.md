# Theme image sources

The internal native alpha imports three reviewed Disco PNGs byte-for-byte from parent SpeedyTapper web commit `923a38e`. Runtime copies live in `App/Resources/Themes/`; exact rollback copies live in `assets/themes/sources/`. All are 1024×1024 PNGs. `Scripts/validate-assets.sh` verifies their hashes, equality, dimensions, and resource count.

| File | Purpose | Parent introduction | SHA-256 |
| --- | --- | --- | --- |
| `disco-concrete-lights.png` | Full-screen reflected-concrete ambience | `13c1b5215c418c391fe9a339e07ad8bb14cfc7f2` | `d63ff3184d5e0d7bbfee63cae56dfad80cb659577f7544a3b7c018c44f5e5da5` |
| `disco-concrete.png` | Retained clean concrete rollback texture | `74362a3b7533302c8ed29919e3276970594394e4` | `4c87e621400040c094a8b8b92f9e822f7739b050792a81870b74a2368fadc0fe` |
| `disco-tile-overlay.png` | Scratched-plastic wear on Disco tiles | `74362a3b7533302c8ed29919e3276970594394e4` | `4d2e24531b091a44cbfeee1371024350818c24a52c7e45ac72a4bd3fef69c095` |

The parent source record describes these as generated concrete/plastic-wear assets and identifies an internal generated-image path as visual truth, but it does not retain complete public-release generation metadata or rights paperwork. They are therefore approved only for the current owner-only internal alpha. Complete provenance/rights review or original replacements remain required before public distribution.

First shipped build: not shipped. The native app translates the reviewed HTML/CSS composition into SwiftUI and SpriteKit; it does not embed the web UI.
