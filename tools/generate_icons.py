"""Regenerate platform icons from assets/branding/devmate_source.png.

Requires Pillow: python3 -m pip install Pillow
Run from any directory: python3 tools/generate_icons.py
"""

from pathlib import Path
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/devmate_source.png"
IMAGE = Image.open(SOURCE).convert("RGB")
RESAMPLE = Image.Resampling.LANCZOS


def save(image: Image.Image, relative: str, size: int) -> None:
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), RESAMPLE).save(target, format="PNG", optimize=True)


# Separate the artwork from the almost-black opaque background. The original
# has no alpha channel; bright green/lavender pixels are the actual logo.
rgb = IMAGE.convert("RGB")
brightness = rgb.convert("HSV").getchannel("V")
alpha = brightness.point(lambda value: max(0, min(255, round((value - 45) * 255 / 105))))
foreground = rgb.copy().convert("RGBA")
foreground.putalpha(alpha)
monochrome = Image.new("RGBA", rgb.size, (255, 255, 255, 0))
monochrome.putalpha(alpha)

# iOS AppIcon: preserve an opaque background, including the marketing icon.
iconset = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
contents = json.loads((iconset / "Contents.json").read_text())
for entry in contents["images"]:
    points = float(entry["size"].split("x")[0])
    scale = int(entry["scale"][0])
    save(IMAGE, f"ios/Runner/Assets.xcassets/AppIcon.appiconset/{entry['filename']}", round(points * scale))

# Traditional Android launcher images; adaptive foreground remains transparent.
densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for density, factor in densities.items():
    save(IMAGE, f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", round(48 * factor))
    save(foreground, f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png", round(108 * factor))
    save(monochrome, f"android/app/src/main/res/mipmap-{density}/ic_launcher_monochrome.png", round(108 * factor))
    save(monochrome, f"android/app/src/main/res/drawable-{density}/ic_stat_devmate.png", round(24 * factor))

# Standard PWA icons, maskable icons, and browser favicon.
for size in (192, 512):
    save(IMAGE, f"web/icons/Icon-{size}.png", size)
    save(IMAGE, f"web/icons/Icon-maskable-{size}.png", size)
save(IMAGE, "web/favicon.png", 48)

print("Generated iOS, Android launcher/adaptive/notification, and Web icons.")
