# Branding sources

The current PimPoPom development app-icon candidate uses the live wordmark colors in an exact stacked `Pim` / `Po` / `Pom` lockup. It remains subject to Home Screen review and final acceptance. The earlier disc-based candidate is retained as the rollback generation.

## PimPoPom stacked-wordmark development app icon

| Field | Value |
| --- | --- |
| Asset name/path | Runtime export: `App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png`; retained final master: `assets/branding/sources/PimPoPom-AppIcon-stacked-master.png`; retained generated backdrop: `assets/branding/sources/PimPoPom-AppIcon-stacked-background-original.png` |
| Creator/tool/model | Backdrop: OpenAI built-in image generation tool, whose underlying model identifier was not exposed; exact wordmark/export: Swift, CoreGraphics, and CoreText renderer |
| Creation date | 2026-07-18 |
| Prompt/brief/reference rights | Full prompt, exact wording, color tokens, layout, and export command retained in `assets/branding/sources/PimPoPom-AppIcon-stacked-prompt.md`; the previous generated icon was supplied to the image tool as a style reference and remains owned within this project |
| Licence/assignment | Generated specifically for PimPoPom under the applicable OpenAI terms; final legal and trademark clearance remains pending |
| Editable master | Deterministic renderer at `assets/branding/sources/render-stacked-app-icon.swift` plus the text-free 1254×1254 generation output; the checked-in 1024×1024 lossless master is identical to the runtime export |
| Export sizes/color profile | 1024×1024 opaque PNG, sRGB IEC61966-2.1; full-bleed square with no baked corner mask |
| SHA-256 | Backdrop: `1bb3e5a24b1148a4640a84d4c9518d5c56bb89cd9448e7b5ac07aa012d6364b4`; final master/runtime: `cf0c5ab761dcbd5a9760b1fe3c1924267139299233bf307bcbc63470196393c7`; prompt: `5b63834c936e99b40d79684f819ce81932a658fadabd25c0347b1df982354c23`; renderer: `4477e88b1817c010fda89fed83d35bd8e6792be2f670e2ac0a5895fe177919e9` |
| First included build | Unreleased internal development candidate for 0.1.0 (1); not installed or shipped |
| Rollback source | Previous disc-based master and prompt below; restore only through a reviewed asset change |

## Previous disc-based development app icon

| Field | Value |
| --- | --- |
| Asset name/path | Runtime export: `App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png`; retained generation master: `assets/branding/sources/PimPoPom-AppIcon-original-1254.png` |
| Creator/tool/model | OpenAI image generation tool; underlying model identifier was not exposed by the tool |
| Creation date | 2026-07-15 |
| Prompt/brief/reference rights | Original text-only brief retained in `assets/branding/sources/PimPoPom-AppIcon-prompt.md`; no reference image was supplied |
| Licence/assignment | Generated specifically for PimPoPom under the applicable OpenAI terms; final legal and trademark clearance remains pending |
| Editable master | No layered/vector master; lossless 1254×1254 PNG generation output retained as the rollback master |
| Export sizes/color profile | 1024×1024 opaque PNG, sRGB IEC61966-2.1; no baked corner mask |
| SHA-256 | Master: `add7d57f719fe1f68faa2fc027d1850649d05a1370551d4e106a6d89ff0d4c06`; runtime export: `2d2eda0e7d22913cd03fbfe94eee8336bf5b7f367856754799d30eac4a392736` |
| First included build | Uncommitted internal development build 0.1.0 (1), installed locally on 2026-07-15; not released |
| Rollback source | Retained lossless generation master and prompt in `assets/branding/sources/` |

## Remaining identity work

- Review and finalize the original **PimPoPom** wordmark/app-icon system; do not reuse the legacy product name or icon.
- Complete name/trademark/domain clearance before final production.
- Review concepts for recognizability at App Store, Home Screen, Spotlight, Settings, notification, and marketing sizes.
- Avoid important detail outside Apple's icon mask/safe composition and do not bake rounded corners into source art unless current platform guidance explicitly calls for it.
- Retain editable vector/layered masters, color definitions, monochrome variants, export presets, prompts and references used for generation, creator/tool identity, licence/assignment, and review contact.
- Hash approved masters and every shipped export. Record the exact app version/build that first includes each asset.

## Record template for future assets

| Field | Value |
| --- | --- |
| Asset name/path | Pending |
| Creator/tool/model | Pending |
| Creation date | Pending |
| Prompt/brief/reference rights | Pending |
| Licence/assignment | Pending |
| Editable master | Pending |
| Export sizes/color profile | Pending |
| SHA-256 | Pending |
| First shipped build | Not shipped |
| Rollback source | Pending |
