# Branding sources

The PimPoPom development app-icon system uses the live wordmark colors in an exact stacked `Pim` / `Po` / `Pom` lockup. The ImageGen Glow primary plus Light and Pixel alternates remain subject to physical Home Screen review and final acceptance. The retired outlined and earlier disc-based candidates are retained only as rollback/provenance sources and are not bundled.

## Retired outlined stacked-wordmark candidate

| Field | Value |
| --- | --- |
| Asset name/path | Retained final master: `assets/branding/sources/PimPoPom-AppIcon-stacked-master.png`; retained generated backdrop: `assets/branding/sources/PimPoPom-AppIcon-stacked-background-original.png`; prompt/renderer retained beside them |
| Creator/tool/model | Backdrop: OpenAI built-in image generation tool, whose underlying model identifier was not exposed; exact wordmark/export: Swift, CoreGraphics, and CoreText renderer |
| Creation date | 2026-07-18 |
| Prompt/brief/reference rights | Full prompt, exact wording, color tokens, layout, and export command retained in `assets/branding/sources/PimPoPom-AppIcon-stacked-prompt.md`; the previous generated icon was supplied to the image tool as a style reference and remains owned within this project |
| Licence/assignment | Generated specifically for PimPoPom under the applicable OpenAI terms; final legal and trademark clearance remains pending |
| Editable master | Deterministic renderer at `assets/branding/sources/render-stacked-app-icon.swift` plus the text-free 1254×1254 generation output; the checked-in 1024×1024 lossless master is retained but no longer shipped |
| Export sizes/color profile | 1024×1024 opaque PNG, sRGB IEC61966-2.1; full-bleed square with no baked corner mask |
| SHA-256 | Backdrop: `1bb3e5a24b1148a4640a84d4c9518d5c56bb89cd9448e7b5ac07aa012d6364b4`; final master/runtime: `cf0c5ab761dcbd5a9760b1fe3c1924267139299233bf307bcbc63470196393c7`; prompt: `5b63834c936e99b40d79684f819ce81932a658fadabd25c0347b1df982354c23`; renderer: `4477e88b1817c010fda89fed83d35bd8e6792be2f670e2ac0a5895fe177919e9` |
| First included build | Implemented at `c7b15d9` as an unreleased 0.1.0 (1) candidate, then removed from the app-icon catalog before physical-device installation or shipment |
| Rollback source | This retained master and renderer; restore only through a reviewed asset change |

## PimPoPom ImageGen Glow primary app icon

| Field | Value |
| --- | --- |
| Asset name/path | Runtime primary: `App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png`; retained reviewed master: `assets/branding/sources/PimPoPom-AppIcon-glow-master.png`; original generation output: `assets/branding/sources/PimPoPom-AppIcon-glow-imagegen-original-1254.png`; Settings preview: `App/Assets.xcassets/AppIconGlowPreview.imageset/PimPoPom-AppIcon-Glow-Preview.png` |
| Creator/tool/model | OpenAI built-in image generation tool; underlying model identifier was not exposed by the tool |
| Creation date | 2026-07-18 |
| Prompt/brief/reference rights | Full edit prompt and exact wording retained in `assets/branding/sources/PimPoPom-AppIcon-glow-imagegen-prompt.md`; the retired project-owned outlined icon was the edit target |
| Licence/assignment | Generated specifically for PimPoPom under the applicable OpenAI terms; final legal and trademark clearance remains pending |
| Editable master | No layered/vector master; the lossless 1254×1254 ImageGen output is retained with the reviewed 1024×1024 export and full prompt |
| Export sizes/color profile | Primary icon: 1024×1024 opaque PNG, sRGB IEC61966-2.1; Settings preview: 180×180 opaque PNG; no baked corner mask |
| SHA-256 | Original: `de744fc396a300358ba98494d5f3c164294194509a2fea6d6bd19a610a8672ed`; final master/runtime: `a7a9553d4c74081e6406e47afe2aab4425ae779334870793d1b6e7844c0bb54c`; prompt: `f49efce8dbb11b7dcc5f8127c9c6b8d1f74943d5bb8f21d727f156cdb7ac7110`; Settings preview: `b080a68cb6e37b5490dcdd3b55ad23acfd3b6fe4512c2f16241e4528d9357c33` |
| First included build | Unreleased internal development candidate for 0.1.0 (1); not installed on physical hardware or shipped |
| Rollback source | Passing `nil` to the native alternate-icon API selects this primary; the complete ImageGen source and prompt are retained |

## PimPoPom ImageGen Light alternate app icon

| Field | Value |
| --- | --- |
| Asset name/path | Runtime alternate: `App/Assets.xcassets/AppIconLight.appiconset/PimPoPom-AppIcon-Light.png`; master: `assets/branding/sources/PimPoPom-AppIcon-light-master.png`; original: `assets/branding/sources/PimPoPom-AppIcon-light-imagegen-original-1254.png`; Settings preview: `App/Assets.xcassets/AppIconLightPreview.imageset/PimPoPom-AppIcon-Light-Preview.png` |
| Creator/tool/model | OpenAI built-in image generation tool; underlying model identifier was not exposed by the tool |
| Creation date | 2026-07-18 |
| Prompt/brief/reference rights | Full prompt retained in `assets/branding/sources/PimPoPom-AppIcon-light-imagegen-prompt.md`; project-owned Glow icon was the edit target and the native Light gameplay capture was a style reference only |
| Licence/assignment | Generated specifically for PimPoPom under the applicable OpenAI terms; final legal and trademark clearance remains pending |
| Editable master | No layered/vector master; the lossless 1254×1254 ImageGen output, reviewed 1024×1024 export, reference path, and prompt are retained |
| Export sizes/color profile | 1024×1024 opaque sRGB alternate icon; 180×180 opaque Settings preview; no baked corner mask |
| SHA-256 | Original: `d03402b44b43ed1e284e2d5700a51dcec0c861fff347b6b826e1b0779fba28c1`; master/runtime: `8090eaee590f161cf81e5d548c2da0675160424a63cf9a03f37e5ea7fe3ed60e`; prompt: `3e1a6f5a4e21eef53fc087516852e6810772b8a865062bf4e63bd3ef35d3ddd3`; preview: `85351303271a3c1b217f27d376faa1a96e32afcf75bac956a520280edef6210c` |
| First included build | Unreleased internal development candidate for 0.1.0 (1); not installed on physical hardware or shipped |
| Rollback source | Select Glow through Settings; this alternate remains independently removable without changing the primary icon |

## PimPoPom ImageGen Pixel alternate app icon

| Field | Value |
| --- | --- |
| Asset name/path | Runtime alternate: `App/Assets.xcassets/AppIconPixel.appiconset/PimPoPom-AppIcon-Pixel.png`; master: `assets/branding/sources/PimPoPom-AppIcon-pixel-master.png`; original: `assets/branding/sources/PimPoPom-AppIcon-pixel-imagegen-original-1254.png`; Settings preview: `App/Assets.xcassets/AppIconPixelPreview.imageset/PimPoPom-AppIcon-Pixel-Preview.png` |
| Creator/tool/model | OpenAI built-in image generation tool; underlying model identifier was not exposed by the tool |
| Creation date | 2026-07-18 |
| Prompt/brief/reference rights | Full prompt retained in `assets/branding/sources/PimPoPom-AppIcon-pixel-imagegen-prompt.md`; project-owned Glow icon was the edit target and the native Pixel menu capture was a style reference only |
| Licence/assignment | Generated specifically for PimPoPom under the applicable OpenAI terms; final legal and trademark clearance remains pending |
| Editable master | No layered/vector master; the lossless 1254×1254 ImageGen output, reviewed 1024×1024 export, reference path, and prompt are retained |
| Export sizes/color profile | 1024×1024 opaque sRGB alternate icon; 180×180 opaque Settings preview; no baked corner mask |
| SHA-256 | Original: `addfded0aa0739efc47580ac908dce78e9fd7133fe485d278d7acd6593d2e15d`; master/runtime: `d32332c4086c6b5022dbee8110ff1ffa24193947b87114071474be69210f0b50`; prompt: `7dd4171700daf7f7457a8a4799ba3a666fe1d65521f3760f581cfafce7dbd3b6`; preview: `da60ef6175cdfe6255eddfa32a2981c4a0844271ed5c51e5b1099f43ac5c5ed3` |
| First included build | Unreleased internal development candidate for 0.1.0 (1); not installed on physical hardware or shipped |
| Rollback source | Select Glow through Settings; this alternate remains independently removable without changing the primary icon |

## Previous disc-based development app icon

| Field | Value |
| --- | --- |
| Asset name/path | Retained generation master: `assets/branding/sources/PimPoPom-AppIcon-original-1254.png`; former runtime export is no longer bundled |
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
