# Marketing asset sources

## App Store launch kit 1.0 draft

- Delivery folder: `release/app-store/1.0/`
- Source build: TestFlight `1.01 (6)`
- Archived source commit: `2d55f71`
- Deterministic renderer: `Scripts/render_app_store_launch_kit.py`
- Storefront UI sources: exported XCUITest attachments from Build 6, copied into `release/app-store/1.0/source/screenshots/` before the transient result bundle is removed.
- Icon source: `App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png`
- Caption font: Apple system SF Rounded on the build Mac. This font is not bundled into or redistributed with the kit; the renderer uses the installed system copy.
- Feature-label font: bundled Jersey 10 source, covered by `assets/fonts/OFL-Jersey10.txt`.
- Ambient backgrounds: two original OpenAI ImageGen outputs retained under `release/app-store/1.0/source/imagegen/`, with exact prompts in `PROMPTS.md`.

ImageGen was constrained to text-free abstract background art. No generated output is evidence of app behavior. App UI, icon, copy, captions, sizes, and claims are composited deterministically from reviewed sources.

Before any public use, also satisfy the independent public-release rights gates documented for pet art, Disco textures, and final PimPoPom branding. This source record does not override those restrictions.
