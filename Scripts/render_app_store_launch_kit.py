#!/usr/bin/env python3
"""Render deterministic PimPoPom App Store and campaign artwork.

Generated backgrounds are used only as ambient campaign art. Every app screen,
icon, caption, and claim is composed from repository-controlled sources.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "release" / "app-store" / "1.0"
SOURCE = KIT / "source"
SCREENSHOT_OUT = KIT / "screenshots" / "6.9-inch"
BANNER_OUT = KIT / "banners"
REVIEW_OUT = KIT / "review"

SCREEN_SIZE = (1260, 2736)  # Accepted 6.9-inch portrait size.
MIDNIGHT = SOURCE / "imagegen" / "midnight-neon-original.png"
CRYSTAL = SOURCE / "imagegen" / "light-crystal-original.png"
ICON = SOURCE / "app-icon.png"
JERSEY = ROOT / "App" / "Resources" / "Fonts" / "jersey-10-regular.ttf"
SF_ROUNDED = Path("/System/Library/Fonts/SFNSRounded.ttf")
ROUNDED_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf")

SCENES = [
    {
        "file": "01-menu.png",
        "output": "01-tiny-taps-giant-scores.png",
        "title": "Tiny taps. Giant scores.",
        "subtitle": "A colorful reflex game made for quick runs.",
        "tag": "ARCADE + ZEN",
        "accent": (64, 231, 207),
    },
    {
        "file": "02-arcade-feedback.png",
        "output": "02-every-millisecond-matters.png",
        "title": "Every millisecond matters.",
        "subtitle": "Tap fast, dodge decoys, and build your Speed Bar.",
        "tag": "REACTION + RHYTHM",
        "accent": (255, 211, 74),
    },
    {
        "file": "03-zen.png",
        "output": "03-find-your-flow.png",
        "title": "Find your flow in Zen.",
        "subtitle": "Endless practice with no lives, deadlines, or rankings.",
        "tag": "ENDLESS PRACTICE",
        "accent": (126, 218, 105),
    },
    {
        "file": "04-theme-shop.png",
        "output": "04-switch-up-your-style.png",
        "title": "Switch up your style.",
        "subtitle": "Choose the look that makes every tap feel yours.",
        "tag": "4 DISTINCT THEMES",
        "accent": (117, 216, 255),
    },
    {
        "file": "05-leaderboard.png",
        "output": "05-chase-the-leaderboard.png",
        "title": "Chase the Arcade leaderboard.",
        "subtitle": "Compare scores, reaction times, and accuracy.",
        "tag": "ARCADE RANKINGS",
        "accent": (255, 217, 67),
    },
    {
        "file": "06-profile.png",
        "output": "06-your-game-in-one-place.png",
        "title": "Your game, all in one place.",
        "subtitle": "Keep your best, achievements, cosmetics, and settings together.",
        "tag": "OPTIONAL SIGN-IN",
        "accent": (255, 111, 179),
    },
]


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def cover(image: Image.Image, size: tuple[int, int], focus_x: float = 0.5, focus_y: float = 0.5) -> Image.Image:
    source_ratio = image.width / image.height
    target_ratio = size[0] / size[1]
    if source_ratio > target_ratio:
        crop_width = int(image.height * target_ratio)
        left = int((image.width - crop_width) * focus_x)
        box = (left, 0, left + crop_width, image.height)
    else:
        crop_height = int(image.width / target_ratio)
        top = int((image.height - crop_height) * focus_y)
        box = (0, top, image.width, top + crop_height)
    return image.crop(box).resize(size, Image.Resampling.LANCZOS)


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        color = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        draw.line((0, y, size[0], y), fill=color)
    return image


def add_glow(canvas: Image.Image, center: tuple[int, int], radius: int, color: tuple[int, int, int], opacity: int) -> None:
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    x, y = center
    draw.ellipse((x - radius // 3, y - radius // 3, x + radius // 3, y + radius // 3), fill=(*color, opacity))
    glow = glow.filter(ImageFilter.GaussianBlur(radius // 2))
    canvas.alpha_composite(glow)


def wrap_text(text: str, face: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    for word in words:
        candidate = f"{current} {word}".strip()
        if probe.textbbox((0, 0), candidate, font=face)[2] <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_wrapped(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    face: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int] | tuple[int, int, int, int],
    max_width: int,
    line_gap: int,
) -> int:
    x, y = xy
    lines = wrap_text(text, face, max_width)
    for line in lines:
        draw.text((x, y), line, font=face, fill=fill, stroke_width=1, stroke_fill=fill)
        bbox = draw.textbbox((x, y), line, font=face)
        y += bbox[3] - bbox[1] + line_gap
    return y


def paste_rounded(canvas: Image.Image, image: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    x0, y0, x1, y1 = box
    fitted = image.resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS).convert("RGBA")
    alpha_composite_masked(canvas, fitted, (x0, y0), rounded_mask(fitted.size, radius))


def alpha_composite_masked(canvas: Image.Image, image: Image.Image, xy: tuple[int, int], mask: Image.Image) -> None:
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    overlay.paste(image, xy, mask)
    canvas.alpha_composite(overlay)


def draw_shadowed_panel(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int, int],
    border: tuple[int, int, int, int],
) -> None:
    x0, y0, x1, y1 = box
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x0 - 14, y0 + 20, x1 + 14, y1 + 34), radius + 12, fill=(0, 0, 0, 190))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(box, radius, fill=fill, outline=border, width=4)


def render_store_screenshot(scene: dict[str, object]) -> Path:
    width, height = SCREEN_SIZE
    canvas = vertical_gradient(SCREEN_SIZE, (10, 15, 45), (4, 7, 20)).convert("RGBA")
    midnight = Image.open(MIDNIGHT).convert("RGBA")
    header = cover(midnight, (width, 690), focus_x=0.38)
    header.putalpha(header.getchannel("A").point(lambda value: int(value * 0.78)))
    canvas.alpha_composite(header, (0, 0))

    accent = scene["accent"]
    assert isinstance(accent, tuple)
    add_glow(canvas, (110, 660), 620, accent, 120)
    add_glow(canvas, (1160, 2210), 700, (88, 67, 255), 105)

    draw = ImageDraw.Draw(canvas)
    icon = Image.open(ICON).convert("RGBA").resize((104, 104), Image.Resampling.LANCZOS)
    icon_mask = rounded_mask(icon.size, 24)
    alpha_composite_masked(canvas, icon, (74, 68), icon_mask)
    draw.text((202, 83), "PimPoPom", font=font(SF_ROUNDED, 54), fill=(245, 249, 255), stroke_width=1)

    title_face = font(ROUNDED_BOLD, 82)
    subtitle_face = font(SF_ROUNDED, 36)
    title_bottom = draw_wrapped(draw, str(scene["title"]), (74, 208), title_face, (255, 255, 255), 1110, 2)
    draw_wrapped(draw, str(scene["subtitle"]), (78, title_bottom + 20), subtitle_face, (199, 211, 239), 1080, 10)

    frame_box = (140, 660, 1120, 2404)
    draw_shadowed_panel(canvas, frame_box, 74, (11, 14, 35, 245), (*accent, 210))
    source = Image.open(SOURCE / "screenshots" / str(scene["file"])).convert("RGB")
    screen_box = (158, 678, 1102, 2386)
    paste_rounded(canvas, source, screen_box, 58)

    pill_text = str(scene["tag"])
    pill_face = font(JERSEY, 44)
    pill_bbox = draw.textbbox((0, 0), pill_text, font=pill_face)
    pill_width = pill_bbox[2] - pill_bbox[0] + 76
    pill_box = (630 - pill_width // 2, 2500, 630 + pill_width // 2, 2592)
    draw.rounded_rectangle(pill_box, 46, fill=(*accent, 38), outline=(*accent, 210), width=3)
    text_width = pill_bbox[2] - pill_bbox[0]
    draw.text((630 - text_width // 2, 2514), pill_text, font=pill_face, fill=(244, 249, 255))
    draw.text((630, 2672), "PimPoPom", anchor="mm", font=font(SF_ROUNDED, 29), fill=(142, 158, 197))

    output = SCREENSHOT_OUT / str(scene["output"])
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output, "PNG", optimize=True)
    return output


def render_banner(
    output: Path,
    size: tuple[int, int],
    background_path: Path,
    light: bool,
) -> Path:
    background = Image.open(background_path).convert("RGBA")
    canvas = cover(background, size, focus_x=0.5 if light else 0.5).convert("RGBA")
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    if light:
        od.rectangle((0, 0, int(size[0] * 0.64), size[1]), fill=(235, 249, 255, 115))
    else:
        od.rectangle((0, 0, int(size[0] * 0.66), size[1]), fill=(2, 7, 30, 112))
    canvas.alpha_composite(overlay)

    scale = size[1] / 1080
    icon_size = max(210, int(330 * scale))
    icon = Image.open(ICON).convert("RGBA").resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    icon_x = int(110 * scale)
    icon_y = (size[1] - icon_size) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((icon_x + 12, icon_y + 22, icon_x + icon_size + 12, icon_y + icon_size + 22), int(78 * scale), fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(18, int(35 * scale))))
    canvas.alpha_composite(shadow)
    alpha_composite_masked(canvas, icon, (icon_x, icon_y), rounded_mask(icon.size, int(72 * scale)))

    draw = ImageDraw.Draw(canvas)
    copy_x = icon_x + icon_size + int(92 * scale)
    title_color = (13, 34, 62) if light else (255, 255, 255)
    secondary = (47, 86, 117) if light else (201, 220, 246)
    headline = "Tap fast.\nFind your flow."
    headline_face = font(ROUNDED_BOLD, max(55, int(84 * scale)))
    line_height = max(62, int(102 * scale))
    copy_y = int(300 * scale)
    for index, line in enumerate(headline.splitlines()):
        draw.text((copy_x, copy_y + index * line_height), line, font=headline_face, fill=title_color, stroke_width=1)
    draw.text(
        (copy_x, copy_y + line_height * 2 + int(28 * scale)),
        "A COLOR REACTION GAME FOR IPHONE",
        font=font(JERSEY, max(28, int(40 * scale))),
        fill=secondary,
    )

    pill_face = font(JERSEY, max(27, int(37 * scale)))
    pill_y = copy_y + line_height * 2 + int(96 * scale)
    cursor = copy_x
    for label, color in [("ARCADE", (255, 87, 164)), ("ZEN", (95, 225, 142)), ("THEMES", (74, 222, 245))]:
        bbox = draw.textbbox((0, 0), label, font=pill_face)
        pill_width = bbox[2] - bbox[0] + int(52 * scale)
        pill_height = max(48, int(64 * scale))
        draw.rounded_rectangle((cursor, pill_y, cursor + pill_width, pill_y + pill_height), pill_height // 2, fill=(*color, 55), outline=(*color, 220), width=max(2, int(3 * scale)))
        draw.text((cursor + int(26 * scale), pill_y + int(8 * scale)), label, font=pill_face, fill=title_color)
        cursor += pill_width + int(18 * scale)

    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output, "PNG", optimize=True)
    return output


def render_contact_sheet(outputs: list[Path]) -> Path:
    thumb_width = 330
    thumb_height = round(thumb_width * SCREEN_SIZE[1] / SCREEN_SIZE[0])
    margin = 44
    gap = 30
    sheet_width = margin * 2 + thumb_width * 3 + gap * 2
    sheet_height = margin * 2 + thumb_height * 2 + gap + 96
    canvas = vertical_gradient((sheet_width, sheet_height), (9, 15, 42), (4, 7, 20)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    draw.text((margin, 25), "PimPoPom · App Store screenshot draft", font=font(SF_ROUNDED, 32), fill=(245, 249, 255))
    for index, output in enumerate(outputs):
        image = Image.open(output).convert("RGBA").resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        x = margin + (index % 3) * (thumb_width + gap)
        y = 86 + (index // 3) * (thumb_height + gap)
        alpha_composite_masked(canvas, image, (x, y), rounded_mask(image.size, 18))
    output = REVIEW_OUT / "app-store-screenshot-contact-sheet.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output, "PNG", optimize=True)
    return output


def render_banner_contact_sheet(banners: list[Path]) -> Path:
    selected = banners[:2]
    thumb_size = (900, 506)
    canvas = vertical_gradient((980, 1190), (9, 15, 42), (4, 7, 20)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    draw.text((40, 28), "PimPoPom · hero banner directions", font=font(SF_ROUNDED, 34), fill=(245, 249, 255))
    labels = ["MIDNIGHT NEON", "LIGHT CRYSTAL"]
    for index, (path, label) in enumerate(zip(selected, labels)):
        y = 92 + index * 545
        image = Image.open(path).convert("RGBA").resize(thumb_size, Image.Resampling.LANCZOS)
        alpha_composite_masked(canvas, image, (40, y), rounded_mask(image.size, 24))
        label_face = font(JERSEY, 30)
        label_box = draw.textbbox((0, 0), label, font=label_face)
        label_width = label_box[2] - label_box[0]
        draw.rounded_rectangle(
            (50, y + 454, 50 + label_width + 28, y + 496),
            18,
            fill=(4, 7, 20, 205),
            outline=(178, 197, 238, 120),
            width=2,
        )
        draw.text((64, y + 460), label, font=label_face, fill=(244, 249, 255))
    output = REVIEW_OUT / "banner-options-contact-sheet.png"
    canvas.convert("RGB").save(output, "PNG", optimize=True)
    return output


def write_manifest(
    screenshots: list[Path],
    banners: list[Path],
    screenshot_contact_sheet: Path,
    banner_contact_sheet: Path,
) -> None:
    payload = {
        "version": "1.0-draft",
        "sourceBuild": "1.01 (6)",
        "sourceCommit": "2d55f71",
        "screenshots": [
            {"path": str(path.relative_to(KIT)), "width": SCREEN_SIZE[0], "height": SCREEN_SIZE[1], "format": "PNG", "alpha": False}
            for path in screenshots
        ],
        "banners": [
            {
                "path": str(path.relative_to(KIT)),
                "width": Image.open(path).width,
                "height": Image.open(path).height,
                "format": "PNG",
                "appStoreField": False,
            }
            for path in banners
        ],
        "review": [
            str(screenshot_contact_sheet.relative_to(KIT)),
            str(banner_contact_sheet.relative_to(KIT)),
        ],
        "notes": [
            "App UI, icon, captions, and product claims are deterministic.",
            "ImageGen output is used only for abstract ambient campaign backgrounds.",
            "Apple App Store Connect has no generic product-page banner field; banner exports are for web, social, press, or future featuring requests.",
        ],
    }
    (KIT / "manifest.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    for directory in (SCREENSHOT_OUT, BANNER_OUT, REVIEW_OUT):
        directory.mkdir(parents=True, exist_ok=True)
    screenshots = [render_store_screenshot(scene) for scene in SCENES]
    banners = [
        render_banner(BANNER_OUT / "pimpopom-hero-dark-1920x1080.png", (1920, 1080), MIDNIGHT, light=False),
        render_banner(BANNER_OUT / "pimpopom-hero-light-1920x1080.png", (1920, 1080), CRYSTAL, light=True),
        render_banner(BANNER_OUT / "pimpopom-social-dark-1200x628.png", (1200, 628), MIDNIGHT, light=False),
        render_banner(BANNER_OUT / "pimpopom-website-dark-2400x1000.png", (2400, 1000), MIDNIGHT, light=False),
    ]
    contact_sheet = render_contact_sheet(screenshots)
    banner_contact_sheet = render_banner_contact_sheet(banners)
    write_manifest(screenshots, banners, contact_sheet, banner_contact_sheet)
    print(
        f"Rendered {len(screenshots)} screenshots, {len(banners)} banners, "
        f"and 2 review sheets"
    )


if __name__ == "__main__":
    main()
