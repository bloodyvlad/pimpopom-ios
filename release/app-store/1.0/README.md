# App Store source kit

Status: retained draft/provenance material, not current release evidence and never
submitted to the production App Store.

The rendered screenshot/contact-sheet assets came from TestFlight `1.01 (6)`,
source `2d55f71`. They are intentionally retained because their UI captures,
ImageGen sources, prompts, and deterministic renderer establish provenance. They
must not be uploaded as current or future production screenshots.

## Current-use map

- `metadata/en-US.md`: current copy draft plus TestFlight build-24 text.
- `game-center/en-US.md`: current configured vendor IDs/copy.
- `legal/`: static Privacy/Support drafts with owner placeholders.
- `source/`: original UI captures and ImageGen generations.
- `review/`, `screenshots/`, `banners/`: historical build-6 render outputs.
- `video-shot-list.md`: recapture plan for a future production candidate.
- `Scripts/render_app_store_launch_kit.py`: deterministic renderer for the retained
  sources; new release assets require new current captures.

ImageGen produced only text-free abstract backgrounds. App UI, icon, text, captions,
and output sizes were composed from repository sources. Exact prompts are in
`source/imagegen/PROMPTS.md`.

Before production submission, replace every stale build-6 screen, close public
branding/pet/Disco rights gates, publish reviewed legal/support URLs, complete
archive-derived privacy/age/ads/IAP answers, and pass the release/physical gates in
`../../../docs/RELEASE.md` and `../../../docs/TESTING.md`.
