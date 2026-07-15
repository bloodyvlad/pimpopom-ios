# Pet asset sources

The internal native alpha copies reviewed runtime pet and habitat PNGs byte-for-byte from the SpeedyTapper repository. The current 64-pixel animal/rabbit sheets were accepted in commit `d4f087e15eeba2f52e5f1a371c205368c457446b`; Muse was accepted in `5a7453b31b1ffbf9eb6972952fd99c6663a07772`. This import was verified against clean web `main` commit `7582b2d0aed4a499796d67ae14b96e31937d543e`. Runtime files live in `App/Resources/Pets/`; exact rollback/source copies live in `assets/pets/sources/`. `Scripts/validate-assets.sh` verifies their hashes, equality, and geometry.

The source repository records Foka, Kesha, Tauta, Misha, Mitsuri, Muse, and their habitats as built with OpenAI image generation plus local chroma-keying, nearest-neighbor reduction, and sheet assembly. Misha was designed against a user-supplied cat photo. Muse was designed from a user-supplied adult photo and accepted pose/layout references; the source repository retains the reviewed chroma and alpha masters. The source record does not contain complete public-release paperwork for every asset, so these copies are approved only for the current owner-only internal migration build until that evidence is completed.

Sprites are transparent `640×64` ten-frame sheets. Habitats are transparent `64×48` two-layer sheets. SwiftUI crops them into `64×64` sprite frames and `32×48` back/front habitat layers with nearest-neighbor rendering.

| Runtime file | Purpose | SHA-256 |
| --- | --- | --- |
| `foka-sprite.png` | Foka baby-seal poses | `26dcd7494a0897bf604482999592919ab64ec7afcde5aaa25062ee381d24dab5` |
| `foka-ice-floe.png` | Foka habitat | `c5f688fd5d642eee66cc5380b34f3c9fcf484e4ff35a2495115757352d55b1c4` |
| `kesha-sprite.png` | Kesha parrot poses | `9c4189fd229994cbef95dfde8d2625f5ee0b09f5d9a51d90ad6bc7efdce3a7f3` |
| `kesha-perch.png` | Kesha habitat | `eed099e09467a82e9455e877a097440958d67f21ec59d7c2da418cfa7712734e` |
| `tauta-sprite.png` | Tauta border-collie poses | `2705e9cb60159d56d11504df5bfc409a0db778ed8a1dfb76159cf74931169a8b` |
| `tauta-bed.png` | Tauta habitat | `b6cf7f5d542a83fe6b986e561edae2d8f323d6dda5a0a7f1993001764225a950` |
| `misha-sprite.png` | Misha grey-cat poses | `49d5a435bc94823e3367f1dcbd94274319b94c16339656221c7b6fcdbf322906` |
| `misha-climber.png` | Misha habitat | `b1bc8948559ca8c309ddfc8111818e738753bc22a3f2fc474669a836fd515848` |
| `mitsuri-sprite.png` | Server-granted Mitsuri rabbit poses | `6962a3e541d1dbbe7beb46fe9e4b28971b20f7fc12c7dc345c49a6e3114cc4aa` |
| `mitsuri-cushion.png` | Mitsuri habitat | `20337c01fbab9bf55ed736a7c6f9dfccbcf28b0cc2bf043c1401a734c72c6c1a` |
| `muse-sprite.png` | Server-granted Muse poses | `e0665d679ea930257242ee3da2669cf38c2b5ddcd466d303d33e35463f39669a` |
| `muse-floor.png` | Muse wooden-floor habitat | `23211c138f0c085db0ba2b429a557cd401ea5e7d7495857b1b591f90d0916887` |

Mitsuri and Muse are not sold in the catalog. The native client displays either only when the backend returns its `specialPetId`; it contains no nickname-based entitlement rule. A special companion temporarily overrides shop presentation without rewriting the player's selected shop pet or visibility state, matching the server-owned web contract.

## Pancake restriction

No Pancake bitmap was copied. The source web art came from a user-supplied recording whose independent redistribution clearance was not established. PimPoPom keeps the server catalog ID and 500-coin price visible for compatibility, but renders clearly labelled code-native placeholder art and disables a new Pancake purchase until original replacement art is approved. This restriction does not rewrite backend ownership for an existing internal player.

First shipped build: not shipped. Rollback checkpoint `fd34cf4` contains no migrated pet assets.
