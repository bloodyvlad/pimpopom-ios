# PimPoPom glow primary app-icon brief

- Date: 2026-07-18
- Tool: OpenAI built-in image generation tool
- Edit target at generation time: the retired outlined stacked icon, then located at `App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png`
- Intended use: default internal-development iOS app icon

## Final image-generation prompt

```text
Use case: precise-object-edit
Asset type: primary iOS app icon, opaque full-bleed square
Input images: Image 1 is the edit target and must remain the composition source.
Primary request: Change only the letter edge treatment. Remove every dark navy or black outline around the three words and replace it with bright self-illuminated, color-matched neon edges plus soft outward glow. The letters themselves should look like luminous glass/neon lettering, brighter than the background, with clean readable contours and no dark stroke.
Text (verbatim): first line "Pim" (P-i-m), second line "Po" (P-o), third line "Pom" (P-o-m). Render each word exactly once and no other text.
Invariants: preserve the exact three-line staggered composition, progressive right indent, word sizes, rounded italic letter shapes, existing green gradient for Pim, yellow/orange/pink gradient for Po, pink/purple/cyan gradient for Pom, deep midnight-navy backdrop, three diffuse background glow zones, cyan terminal ring, square framing, and generous iOS mask-safe margins.
Lighting/mood: vivid polished mobile-game neon; the letter glow should be clearly visible and attractive at Home Screen size without blooming enough to blur the spelling.
Constraints: no black or dark outline on any letter; no added icons, discs, buttons, mascots, symbols, borders, corner mask, mockup, watermark, or extra objects; no spelling changes; no duplicated or missing letters; opaque full-bleed square.
```

## Retained exports

- Original 1254×1254 image-generation output: `PimPoPom-AppIcon-glow-imagegen-original-1254.png`
- Reviewed 1024×1024 sRGB master: `PimPoPom-AppIcon-glow-master.png`
- Runtime primary icon: `App/Assets.xcassets/AppIcon.appiconset/PimPoPom-AppIcon.png`
- Settings preview: `App/Assets.xcassets/AppIconGlowPreview.imageset/PimPoPom-AppIcon-Glow-Preview.png`

The original output is downsampled to 1024×1024 and assigned the sRGB IEC61966-2.1 profile with `sips`. No corner mask is baked into any export.
