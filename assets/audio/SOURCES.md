# Audio sources

This record covers the audio included in the internal native alpha. Runtime hashes, retained-master hashes, and pet hashes are machine-checked by `Scripts/validate-assets.sh` against `Scripts/asset-hashes.sha256`.

## Migrated theme suites and life-loss cue

The four theme suites and shared life-loss cue were copied byte-for-byte from the SpeedyTapper repository at commit `087cd018900cb5f04a85ace20bc99db05a0b7fbc` on 2026-07-15. That source record describes them as original deterministic SpeedyTapper material with no third-party samples or external royalty requirement. PimPoPom retains the exact generators and lossless masters under `assets/audio/generation/` and `assets/audio/masters/`; the application target contains only runtime files under `App/Resources/Audio/`.

Each music runtime is 48 kHz stereo AAC-LC and exactly 12 seconds. Each tap bank is 48 kHz, 16-bit mono PCM with sixteen 500 ms slots: 420 ms of authored sound plus an exact 80 ms zero tail. The life-loss cue is 48 kHz, 16-bit mono PCM and 620 ms. Native mixing applies `0.375 × Sound FX volume` to taps/loss/sting and `0.42 × Music volume` to menu/gameplay loops.

| Theme | Identity | Runtime menu / gameplay / tap-bank SHA-256 |
| --- | --- | --- |
| Default | Daylight Circuit, 80 BPM | `2780f58ed60af07443d0a216d7ec6942b321c957bfa167743fa7ddf62d10774b` / `bf8431818ac484d10679090a62098e3dc426487981c2e4d9e2bc9dc6134401b7` / `f880c81515b731c867c8f50bae64187dce0af00930c2559a692d52e36b96764c` |
| Disco | Mirror Circuit, 120 BPM | `da77a7b82e26989ee04de8aadaab188d90f866fd32ee80ad3507335e9c671ea0` / `d811692605582c5e4f1009a7f16fde1f2aeedb3b21ac4c693abe145abe9e91c4` / `e5727ef9aaa53887f4d90ee5bd4d65c9a8a0250d5db38855c908b1418fc4c6db` |
| Light | Open Sky, 100 BPM | `7c4edae3506caa5420905af1042ed0e1f056c48ed4b3812f9936aa8308ae6a1b` / `bbd570a178c0bd7e8d01fb424350a8bdb8da486e1e899af07ea7289895cd5360` / `2cf853df10af1127b8e08dbc6f1bb83858dbe8aa1ff8be842ca9e1dd17d25405` |
| Pixel | Coin-Op Spark, 160 BPM | `ba83ea167d7d14c9c971acc4892b034ccfc9795d2e32406da20a53f887c5520b` / `852ccc3baf7485e26be337efe936de7a20c175eefaa4dfa655afb1856a4e73d5` / `c24bbce2ed562ed2878c646b2f08098ecf3736b6a34a34690a9cb4a250065939` |

Shared life-loss runtime `audio-oops.wav` SHA-256: `d8c80dc7962a92d504aa51dc8c383fffd8279fc83a4ef90cd288c10a66cebb31`.

Retained lossless music-master hashes:

- Default gameplay/menu: `89182fd3b2e994c1b4fe0396b8178d96d8e3b45267e9741412a06a3f3d35d948` / `bee6465aac2573c868052cea083ede4c4531396c953568a9bd67cf58aaef64a6`.
- Disco gameplay/menu: `8bb5d99ea642c795c0ec7eac966c44a69dbaa86aa0b046c9c71bd8e5ffd9935b` / `2b232d90e542d3021559da52f22d421f4658cc231f515d0de6ba2e77f4fa2d7f`.
- Light gameplay/menu: `bb91989662473dcae4d257231b606e6f6d41384f6debaa4616c3ccc7dbd5d485` / `b0e91aa0c01acb32480d69d8c44f515dd5a5ad7d26810d8844735b3dd698ef8d`. This corrects a malformed 62-character menu-master hash in the source repository record.
- Pixel gameplay/menu: `0e176913a78f81f871fd49b7f3f0b323dd4a28fb2aaa8896dbe474d60242ef6b` / `6f423c32d39596d16351c82a663c6cbcc5e3df83039477f6abe8bcbd22e7d97a`.

The copied AAC files retain their original embedded `artist=SpeedyTapper` metadata so their exact bytes and hashes remain auditable. Changing branding metadata requires a separately measured derivative and new hash.

## Original PimPoPom activation cue

`audio-pimpopom-sting.wav` is an original deterministic formant-synthesis candidate created for this native alpha. It contains no human or model-generated voice, recording, or third-party sample. `assets/audio/generation/generate-pimpopom-sting.py` uses NumPy oscillators and seeded noise to generate three voice-like syllables with rising fundamental ranges: Pim `158–174 Hz`, Po `205–224 Hz`, Pom `258–286 Hz`.

| Field | Value |
| --- | --- |
| Runtime | `App/Resources/Audio/audio-pimpopom-sting.wav`; 48 kHz, 16-bit mono PCM; 1.069979 s |
| Runtime measurements | Approximately `-13.1 LUFS`, `-0.6 dBTP` before the app's `0.375` Sound FX gain |
| Runtime SHA-256 | `b25d011ae6c4ee952e58e1cda0894b308b79e315ca23bed6f117e487e3a4a964` |
| Lossless master | `assets/audio/masters/pimpopom-launch-sting-24bit.wav`; 48 kHz, 24-bit mono PCM |
| Master SHA-256 | `82eae27528b07ae75cee8613960f6cae4a41e451b539c0159959920b7806dfcb` |
| Generator/tool | Repository script plus NumPy; deterministic RNG seed `0x50494D504F504F4D` |
| Licence/source | Original project-authored synthesis; no external source input |
| First shipped build | Not shipped; internal-alpha candidate only |
| Rollback | Git checkpoint `fd34cf4` contains the proven alpha without this cue |

The system launch screen remains silent. The app requests this cue once after its SwiftUI root becomes active, only when Sound Effects are enabled. It plays only if decoded within one second; otherwise it is discarded rather than delivered late. It never blocks navigation or gameplay.

## Acceptance state

Automated hashes, formats, duration, and build integration are verified. Listening quality, mix balance, tap latency, loop seams, Silent switch, speakers/headphones/Bluetooth, interruption, and route recovery still require physical-iPhone review before any audio is described as device-validated or accepted for public release.
