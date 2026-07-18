# PimPoPom stacked app-icon brief

- Date: 2026-07-18
- Tool: OpenAI built-in image generation tool plus deterministic Swift/CoreGraphics composition
- Reference image: the retained first PimPoPom app-icon candidate
- Intended use: internal-development iOS app icon

## Requested lockup

The three words must be spelled exactly once and arranged as three descending lines with a progressive right indent:

```text
Pim
 Po
  Pom
```

The deterministic overlay uses the live code-native wordmark colors:

- `Pim`: `#16b887` → `#39c85f` → `#86bd3c`
- `Po`: `#ffe659` → `#ff9a56` → `#ff6fc8`
- `Pom`: `#ff6fc8` → `#a58aff` → `#69d7ff`

Typography is SF Rounded Black with a reproducible 0.11 shear to match the heavy rounded italic app wordmark. The lines share one size and use 95-pixel progressive left indents. A small cyan glow ring retains the wordmark's existing terminal accent.

## Image-generation prompt

Use case: logo-brand

Asset type: 1024×1024 production iOS app-icon background, opaque full-bleed square

Input images: Image 1 is the current PimPoPom icon and the style reference only.

Primary request: Transform Image 1 into a clean atmospheric backdrop for a new stacked PimPoPom wordmark icon. Remove all three circular buttons/discs and every foreground object. Preserve the deep midnight-navy luminous atmosphere and premium playful game feel.

Scene/backdrop: full-bleed deep navy, subtly brighter toward the center. Add three restrained diffuse glow zones descending diagonally from upper-left toward lower-right: green/cyan for the future `Pim` line, warm yellow/orange/pink for `Po`, and pink/purple/cyan for `Pom`. Very faint concentric tap-pulse echoes may sit inside those glow zones, but they must stay abstract and low contrast.

Composition/framing: generous iOS mask-safe margins; quiet center field designed to receive three large staggered text lines at approximately y=220, 470, and 720, each successive line indented slightly to the right.

Style/medium: polished flat/vector-like mobile game branding with subtle dimensional light, smooth and uncluttered.

Constraints: background treatment only; absolutely no text, letters, numerals, words, icons, discs, buttons, hands, mascots, borders, corner masks, mockups, watermarks, or extra objects. Opaque square artwork. Preserve small-size clarity.

## Deterministic export

Run from the repository root:

```bash
swift assets/branding/sources/render-stacked-app-icon.swift
```

The script reads `PimPoPom-AppIcon-stacked-background-original.png` and writes the retained 1024×1024 master plus the asset-catalog runtime export. The generated 1254×1254 background remains unchanged as generation evidence.
