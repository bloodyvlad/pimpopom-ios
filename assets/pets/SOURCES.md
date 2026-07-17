# Pet asset sources

The internal native alpha copies reviewed runtime pet and habitat PNGs byte-for-byte from the SpeedyTapper repository, except for the native-only Pancake replacement documented below. The current 64-pixel animal/rabbit sheets were accepted in commit `d4f087e15eeba2f52e5f1a371c205368c457446b`; Muse was accepted in `5a7453b31b1ffbf9eb6972952fd99c6663a07772`. PHP visual behavior was most recently compared with clean web `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0` on 2026-07-17. Runtime files live in `App/Resources/Pets/`; exact rollback/source copies live in `assets/pets/sources/`. `Scripts/validate-assets.sh` verifies their hashes, equality, and geometry.

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
| `pancake-sprite.png` | Pancake directional/action/sleep poses | `2791d84dc3d426d381ca1d95abe3727fb16905228bd137213231bd8cc58f7141` |
| `pancake-floor.png` | Pancake glowing blue-floor habitat | `b233a05fe66cf057a91ace583dccc1810d5c2700ccd003c9564e4fa07e5f212f` |

Mitsuri and Muse are not sold in the catalog. The native client displays either only when the backend returns its `specialPetId`; it contains no nickname-based entitlement rule. A special companion temporarily overrides shop presentation without rewriting the player's selected shop pet or visibility state, matching the server-owned web contract.

## Pancake native replacement

On 2026-07-17 the owner supplied and explicitly requested use of `assets/pets/sources/chroma/pancake-concept-reference.png` (SHA-256 `285d2fadf5e2ee1e43dd2160f8fb9793aec83b6370f6249b804be0a52d4ba405`) as the identity reference for a new native Pancake. The original attachment contains a pixel-art Pancake pose board and three floor concepts on a magenta chroma background.

Codex built-in image generation produced two retained, unmodified sources:

- `pancake-directional-source.png` (SHA-256 `2e171e534fa3d8a6fe6e729ec45c4def8c0b1c6d43a744564eb2aef80ba69b1d`), from a prompt requesting a crisp ten-pose 5×2 directional/action/settle/sleep sheet in exact native frame order, preserving the supplied Pancake's face, butter, syrup, limbs, palette, and pixel-art character identity on a solid `#FF00FF` background with no platform or text.
- `pancake-floor-source.png` (SHA-256 `f965141c57d6663dad1e39b44e5b379c34237d526e8fcfc86ca8f54a5426a846`), from a prompt requesting one centered cyan/blue glowing pixel floor based on the supplied middle floor concept, on solid `#FF00FF`, with no character, text, or extra objects.

The image-generation result paths at creation time were `/Users/vlad/.codex/generated_images/019f6266-a812-7ef2-97e3-9942a044849e/exec-fa75387b-0ee0-419b-ae6b-9b6a20ca5955.png` and `/Users/vlad/.codex/generated_images/019f6266-a812-7ef2-97e3-9942a044849e/exec-607e6846-4998-49d9-9639-ef42efd0fac0.png`. These paths are provenance only; retained repo sources are authoritative for rollback.

The standard imagegen chroma helper ran with `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`, producing the retained alpha masters under `assets/pets/sources/alpha/`. `Scripts/build-pancake-assets.swift` then uses deterministic nearest-neighbor sampling and binary alpha to create the `640×64` ten-frame runtime sprite and `64×48` two-layer habitat. The right habitat layer is deliberately transparent so the blue floor never obscures the character.

The owner approved this replacement for the internal port by requesting it from the supplied concept. Public-release ownership/redistribution evidence still needs the later legal review already deferred for all generated pet art; this is not a statement of third-party clearance.

First shipped build: not shipped. Rollback checkpoint `fd34cf4` contains no migrated pet assets.
