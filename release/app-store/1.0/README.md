# PimPoPom App Store launch kit

Status: **draft for owner review**. These assets were prepared from TestFlight build `1.01 (6)` and archived source commit `2d55f71`. Nothing in this folder has been submitted to the production App Store version.

## Review first

- [`review/app-store-screenshot-contact-sheet.png`](review/app-store-screenshot-contact-sheet.png) — all six proposed storefront screenshots at a glance.
- [`review/banner-options-contact-sheet.png`](review/banner-options-contact-sheet.png) — dark-neon and Light/crystal hero directions side by side.
- [`banners/pimpopom-hero-dark-1920x1080.png`](banners/pimpopom-hero-dark-1920x1080.png) — primary dark campaign direction.
- [`banners/pimpopom-hero-light-1920x1080.png`](banners/pimpopom-hero-light-1920x1080.png) — alternate Light/crystal direction.
- [`metadata/en-US.md`](metadata/en-US.md) — copy-ready English (U.S.) metadata.
- [`launch-checklist.md`](launch-checklist.md) — launch gates and App Store Connect sequence.
- [`video-shot-list.md`](video-shot-list.md) — optional 25-second App Preview plan.

## Upload mapping

The six PNG files in `screenshots/6.9-inch/` are 1260×2736, RGB, and have no alpha channel. Apple accepts that as one of the 6.9-inch portrait sizes. Upload them in numbered order for English (U.S.). One 6.9-inch set is normally sufficient when the same UI applies to smaller displays; App Store Connect performs the downscaling.

The banner files are for the PimPoPom website, social sharing, press, or a future Apple featuring request. App Store Connect has no generic product-page “banner” field.

## What is real and what is generated

- Every app screen is an untouched Build 6 UI capture with deterministic fictional test data.
- The app icon is the shipped repository asset.
- Captions, feature labels, crops, and output sizes are rendered deterministically by [`Scripts/render_app_store_launch_kit.py`](../../../Scripts/render_app_store_launch_kit.py).
- ImageGen created only the abstract midnight-neon and light-crystal background art. It did not generate app UI, words, logos, pets, scores, or purchase claims. Exact prompts are retained in [`source/imagegen/PROMPTS.md`](source/imagegen/PROMPTS.md).

Run from the repository root:

```sh
python3 Scripts/render_app_store_launch_kit.py
```

## Public-release blockers

Do not submit the production app until these are closed:

1. Retain public-release rights evidence for every bundled pet asset and the Disco texture set. Their current source records approve internal migration use but explicitly leave public distribution pending.
2. Complete final PimPoPom trademark/brand clearance and confirm the exact rights-owning seller/copyright entity.
3. Publish and verify Privacy Policy, Support, Terms, and account-deletion URLs.
4. Complete the archive-derived App Privacy answers, production AdMob/UMP review, StoreKit Sandbox/Production verification, and the remaining gates in [`launch-checklist.md`](launch-checklist.md).

Jersey 10 is already covered by the retained SIL Open Font License 1.1.
