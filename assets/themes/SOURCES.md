# Theme image sources

The iOS beta imports three reviewed Disco PNGs byte-for-byte from SpeedyTapper web
commit `923a38e`. Runtime copies live in `App/Resources/Themes/`; rollback copies
live in `assets/themes/sources/`. All are 1024×1024 PNGs and are hash/geometry
checked by `Scripts/validate-assets.sh`.

| File | Purpose | Parent introduction | SHA-256 |
| --- | --- | --- | --- |
| `disco-concrete-lights.png` | Full-screen reflected-concrete ambience | `13c1b5215c418c391fe9a339e07ad8bb14cfc7f2` | `d63ff3184d5e0d7bbfee63cae56dfad80cb659577f7544a3b7c018c44f5e5da5` |
| `disco-concrete.png` | Retained clean concrete rollback texture | `74362a3b7533302c8ed29919e3276970594394e4` | `4c87e621400040c094a8b8b92f9e822f7739b050792a81870b74a2368fadc0fe` |
| `disco-tile-overlay.png` | Scratched-plastic wear on Disco tiles | `74362a3b7533302c8ed29919e3276970594394e4` | `4d2e24531b091a44cbfeee1371024350818c24a52c7e45ac72a4bd3fef69c095` |

The source record describes generated concrete/plastic-wear assets but does not
retain complete production-release metadata/rights paperwork. TestFlight inclusion
does not close that gate; complete review or original replacement remains required.

Distribution status: bundled in TestFlight 1.02 (20), not production-cleared. The
native app translates the composition into SwiftUI/SpriteKit and embeds no web UI.
