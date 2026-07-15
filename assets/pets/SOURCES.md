# Pet asset sources

The internal native alpha copies reviewed runtime pet and habitat PNGs byte-for-byte from the SpeedyTapper repository at commit `087cd018900cb5f04a85ace20bc99db05a0b7fbc`. Runtime files live in `App/Resources/Pets/`; exact rollback/source copies live in `assets/pets/sources/`. `Scripts/validate-assets.sh` verifies their hashes, equality, and geometry.

The source repository records Foka, Kesha, Tauta, Misha, Mitsuri, and their habitats as built with OpenAI image generation plus local chroma-keying, nearest-neighbor reduction, and sheet assembly. Misha was designed against a user-supplied cat photo. The source record does not retain complete prompt/licence/assignment paperwork for every file, so these copies are approved only for the current owner-only internal migration build until that release evidence is completed.

Sprites are transparent `320×32` ten-frame sheets. Habitats are transparent `64×48` two-layer sheets. SwiftUI crops them into `32×32` sprite frames and `32×48` back/front habitat layers with nearest-neighbor rendering.

| Runtime file | Purpose | SHA-256 |
| --- | --- | --- |
| `foka-sprite.png` | Foka baby-seal poses | `554a0a4d6cecbfae60cf1f4ab7da73b63a5afd0820d9fdaf746bc3fb58b6bc0f` |
| `foka-ice-floe.png` | Foka habitat | `c5f688fd5d642eee66cc5380b34f3c9fcf484e4ff35a2495115757352d55b1c4` |
| `kesha-sprite.png` | Kesha parrot poses | `7dfa0e64e5f86be0ffa2012b94b83e98b32131af717ebefcf0720098413ff865` |
| `kesha-perch.png` | Kesha habitat | `eed099e09467a82e9455e877a097440958d67f21ec59d7c2da418cfa7712734e` |
| `tauta-sprite.png` | Tauta border-collie poses | `0c6fd9d5124aa49ad8d396f921308c97f49cb657d336fc54037e3f568411973d` |
| `tauta-bed.png` | Tauta habitat | `b6cf7f5d542a83fe6b986e561edae2d8f323d6dda5a0a7f1993001764225a950` |
| `misha-sprite.png` | Misha grey-cat poses | `e9a0fb69ab36a1328f56e5055d157f0b88980cdd717876a524cdc800bc788747` |
| `misha-climber.png` | Misha habitat | `b1bc8948559ca8c309ddfc8111818e738753bc22a3f2fc474669a836fd515848` |
| `mitsuri-sprite.png` | Server-granted Mitsuri rabbit poses | `3738cccc59ad1471cccc8122920329a0ecb100c147aa73cbef314b8796741d26` |
| `mitsuri-cushion.png` | Mitsuri habitat | `20337c01fbab9bf55ed736a7c6f9dfccbcf28b0cc2bf043c1401a734c72c6c1a` |

Mitsuri is not sold in the catalog. The native client displays it only when the backend returns `specialPetId`; it contains no nickname-based entitlement rule.

## Pancake restriction

No Pancake bitmap was copied. The source web art came from a user-supplied recording whose independent redistribution clearance was not established. PimPoPom keeps the server catalog ID and 500-coin price visible for compatibility, but renders clearly labelled code-native placeholder art and disables a new Pancake purchase until original replacement art is approved. This restriction does not rewrite backend ownership for an existing internal player.

First shipped build: not shipped. Rollback checkpoint `fd34cf4` contains no migrated pet assets.
