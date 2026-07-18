# PimPoPom Pixel alternate app-icon brief

- Date: 2026-07-18
- Tool: OpenAI built-in image generation tool
- Edit target: the reviewed PimPoPom glow icon
- Style reference: `docs/evidence/2026-07-17/ec71d21-13-pro-pixel-menu.png`
- Intended use: selectable internal-development iOS Pixel-theme alternate app icon

## Final image-generation prompt

```text
Use case: style-transfer
Asset type: selectable Pixel-theme iOS app icon, opaque full-bleed square
Input images: Image 1 is the edit target and composition source. Image 2 is a Pixel-theme style and palette reference only; do not copy its interface, labels, buttons, status bar, panels, or layout.
Primary request: Restyle Image 1 as the PimPoPom Pixel-theme icon. Preserve the exact stacked wordmark composition but rebuild the letters as crisp chunky pixel-art lettering with stepped square edges, tiny controlled square highlights, and a restrained one- to two-pixel neon glow. Replace the smooth background with a deep midnight navy pixel-grid field and subtle brighter square noise. Pixelate the cyan terminal ring too. Do not use smooth rounded lettering and do not add dark or black outlines around the letters.
Text (verbatim): first line "Pim" (P-i-m), second line "Po" (P-o), third line "Pom" (P-o-m). Render each word exactly once and no other text.
Invariants: preserve the three-line staggered composition, progressive right indent, approximate word sizes, green Pim gradient, yellow/orange/pink Po gradient, pink/purple/cyan Pom gradient, terminal cyan ring, square framing, and generous iOS mask-safe margins.
Style/medium: authentic polished pixel art, sharp nearest-neighbor appearance, retro arcade console, readable at small Home Screen size.
Lighting/mood: dark energetic neon arcade; high contrast without excessive bloom.
Constraints: no smooth vector curves; no black or dark letter outline; no interface, panels, buttons, coins, trophies, pets, game tiles, status bar, phones, border, corner mask, mockup, watermark, or extra objects; no spelling changes; no duplicated or missing letters; opaque full-bleed square.
```

## Retained exports

- Original 1254×1254 image-generation output: `PimPoPom-AppIcon-pixel-imagegen-original-1254.png`
- Reviewed 1024×1024 sRGB master: `PimPoPom-AppIcon-pixel-master.png`
- Runtime alternate icon: `App/Assets.xcassets/AppIconPixel.appiconset/PimPoPom-AppIcon-Pixel.png`
- Settings preview: `App/Assets.xcassets/AppIconPixelPreview.imageset/PimPoPom-AppIcon-Pixel-Preview.png`

The original output is downsampled to 1024×1024 and assigned the sRGB IEC61966-2.1 profile with `sips`. No corner mask is baked into any export.
