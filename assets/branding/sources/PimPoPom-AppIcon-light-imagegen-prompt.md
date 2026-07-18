# PimPoPom Light alternate app-icon brief

- Date: 2026-07-18
- Tool: OpenAI built-in image generation tool
- Edit target: the reviewed PimPoPom glow icon
- Style reference: `docs/evidence/2026-07-17/ec71d21-se-light-game.png`
- Intended use: selectable internal-development iOS Light-theme alternate app icon

## Final image-generation prompt

```text
Use case: style-transfer
Asset type: selectable Light-theme iOS app icon, opaque full-bleed square
Input images: Image 1 is the edit target and composition source. Image 2 is a Light-theme style and palette reference only; do not copy its interface, labels, buttons, status bar, game board, or layout.
Primary request: Restyle Image 1 as the PimPoPom Light-theme icon. Preserve the exact stacked wordmark composition while transforming the dark atmosphere into a clean pale sky-blue to icy-white luminous backdrop. Make the letters feel like polished translucent crystal/glass candy with vivid original color gradients, bright white specular rims, subtle internal reflections, and soft color-matched glow. There must be no dark or black letter outline.
Text (verbatim): first line "Pim" (P-i-m), second line "Po" (P-o), third line "Pom" (P-o-m). Render each word exactly once and no other text.
Invariants: preserve the exact three-line staggered composition, progressive right indent, word sizes, rounded italic letter shapes, green Pim gradient, yellow/orange/pink Po gradient, pink/purple/cyan Pom gradient, cyan terminal ring, square framing, and generous iOS mask-safe margins.
Style/medium: premium native mobile-game icon; airy Light-theme glass, smooth sky gradient, crisp small-size readability.
Lighting/mood: bright daylight, optimistic, clean, luminous; enough contrast for the colored words to remain readable on a pale background.
Constraints: no black or dark outline on letters; no interface, panels, buttons, game tiles, status bar, phones, mascots, symbols, border, corner mask, mockup, watermark, or extra objects; no spelling changes; no duplicated or missing letters; opaque full-bleed square.
```

## Retained exports

- Original 1254×1254 image-generation output: `PimPoPom-AppIcon-light-imagegen-original-1254.png`
- Reviewed 1024×1024 sRGB master: `PimPoPom-AppIcon-light-master.png`
- Runtime alternate icon: `App/Assets.xcassets/AppIconLight.appiconset/PimPoPom-AppIcon-Light.png`
- Settings preview: `App/Assets.xcassets/AppIconLightPreview.imageset/PimPoPom-AppIcon-Light-Preview.png`

The original output is downsampled to 1024×1024 and assigned the sRGB IEC61966-2.1 profile with `sips`. No corner mask is baked into any export.
