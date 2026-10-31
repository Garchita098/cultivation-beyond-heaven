#!/usr/bin/env python3
"""Procedural placeholder icons. The live cultivator is a shader; these files keep asset paths ready."""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BG = (11, 14, 23, 255)
QI = (92, 225, 255, 255)
JADE = (61, 219, 160, 255)
GOLD = (240, 199, 94, 255)
DAO = (167, 139, 250, 255)
MUTED = (139, 151, 176, 255)
PANEL = (20, 26, 42, 255)


def save(im: Image.Image, rel: str) -> None:
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, "PNG")
    print(rel)


def icon_base(size: int = 128) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def circle(draw, box, fill, outline=None, width=2):
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def tab_icon(kind: str) -> Image.Image:
    im, d = icon_base(96)
    color = {"cultivation": QI, "upgrades": JADE, "ranks": GOLD, "talents": DAO, "artifacts": GOLD, "rebirth": DAO, "research": QI}[kind]
    if kind == "cultivation":
        d.ellipse((34, 18, 62, 46), outline=color, width=4)
        d.line((48, 46, 48, 62), fill=color, width=4)
        d.line((48, 54, 28, 70), fill=color, width=4)
        d.line((48, 54, 68, 70), fill=color, width=4)
        d.polygon([(22, 78), (48, 66), (74, 78), (48, 86)], outline=color)
    elif kind == "upgrades":
        d.polygon([(48, 16), (72, 46), (58, 46), (58, 80), (38, 80), (38, 46), (24, 46)], fill=color)
    elif kind == "ranks":
        d.rounded_rectangle((22, 58, 74, 78), radius=4, outline=color, width=4)
        d.rounded_rectangle((30, 38, 66, 58), radius=4, outline=color, width=4)
        d.rounded_rectangle((38, 18, 58, 38), radius=4, outline=color, width=4)
    elif kind == "talents":
        d.regular_polygon((48, 48, 28), 4, rotation=0, outline=color, width=4)
        circle(d, (40, 40, 56, 56), color)
    elif kind == "artifacts":
        d.line((30, 70, 66, 28), fill=color, width=6)
        d.polygon([(62, 18), (78, 28), (66, 36)], fill=color)
        d.rectangle((24, 66, 40, 78), outline=color, width=3)
    elif kind == "rebirth":
        d.arc((20, 20, 76, 76), 30, 300, fill=color, width=5)
        d.polygon([(70, 22), (82, 30), (66, 36)], fill=color)
    else:
        circle(d, (28, 28, 68, 68), None, color, 4)
        d.line((48, 40, 48, 58), fill=color, width=3)
        circle(d, (44, 62, 52, 70), color)
    return im


def upgrade_icon(kind: str) -> Image.Image:
    im, d = icon_base(96)
    circle(d, (8, 8, 88, 88), PANEL, QI, 3)
    if kind == "breath_meditation":
        d.arc((24, 28, 72, 68), 200, 340, fill=QI, width=4)
        d.arc((30, 36, 66, 72), 20, 160, fill=QI, width=4)
    elif kind == "body_tempering":
        d.rounded_rectangle((34, 22, 62, 58), radius=10, outline=JADE, width=4)
        d.ellipse((40, 58, 56, 74), outline=JADE, width=3)
    elif kind == "meridian_opening":
        for y in (30, 48, 66):
            circle(d, (40, y - 6, 56, y + 6), QI)
        d.line((48, 30, 48, 66), fill=QI, width=2)
    elif kind == "spirit_sense":
        d.ellipse((28, 34, 68, 66), outline=DAO, width=4)
        circle(d, (42, 44, 54, 56), DAO)
    elif kind == "qi_sea_expansion":
        d.arc((22, 40, 74, 78), 200, 340, fill=QI, width=4)
        d.arc((28, 32, 68, 70), 200, 340, fill=QI, width=3)
    elif kind == "foundation_pill":
        d.rounded_rectangle((36, 28, 60, 70), radius=12, outline=JADE, width=4)
        d.line((40, 46, 56, 46), fill=GOLD, width=3)
    elif kind == "core_flame":
        d.polygon([(48, 18), (64, 50), (56, 50), (60, 78), (36, 48), (46, 48)], fill=GOLD)
    elif kind == "swift_circulation":
        d.arc((24, 24, 72, 72), 20, 300, fill=QI, width=4)
        d.polygon([(66, 22), (78, 28), (64, 36)], fill=QI)
    else:
        d.rounded_rectangle((30, 22, 66, 74), radius=4, outline=GOLD, width=3)
        d.line((36, 40, 60, 40), fill=MUTED, width=2)
        d.line((36, 50, 56, 50), fill=MUTED, width=2)
    return im


def qi_orb() -> Image.Image:
    im, d = icon_base(128)
    circle(d, (16, 16, 112, 112), (20, 40, 56, 255), QI, 4)
    circle(d, (40, 36, 72, 68), (180, 245, 255, 180))
    d.arc((28, 28, 100, 100), 200, 40, fill=QI, width=3)
    return im


def app_icon(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), BG)
    d = ImageDraw.Draw(im)
    m = size * 0.12
    circle(d, (m, m, size - m, size - m), (16, 24, 40, 255), QI, max(2, size // 48))
    inner = size * 0.34
    circle(d, (inner, inner, size - inner, size - inner), None, GOLD, max(2, size // 64))
    c = size / 2
    r = size * 0.06
    circle(d, (c - r, c - r, c + r, c + r), QI)
    return im


def silhouette() -> Image.Image:
    im = Image.new("RGBA", (512, 768), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    col = (8, 10, 18, 255)
    d.ellipse((216, 80, 296, 170), fill=col)
    d.polygon([(256, 160), (200, 420), (312, 420)], fill=col)
    d.polygon([(200, 400), (80, 560), (180, 520)], fill=col)
    d.polygon([(312, 400), (430, 560), (332, 520)], fill=col)
    d.polygon([(180, 500), (60, 640), (250, 620), (250, 500)], fill=col)
    d.polygon([(332, 500), (450, 640), (262, 620), (262, 500)], fill=col)
    return im


def aura(color: tuple[int, int, int]) -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    px = im.load()
    cx = cy = 256
    for y in range(512):
        for x in range(512):
            dist = math.hypot(x - cx, y - cy) / 256.0
            ring = math.exp(-((dist - 0.55) ** 2) / 0.01)
            glow = math.exp(-(dist ** 2) / 0.18)
            a = int(min(255, (ring * 0.85 + glow * 0.35) * 255))
            if a > 4:
                px[x, y] = (color[0], color[1], color[2], a)
    return im


def background() -> Image.Image:
    im = Image.new("RGBA", (720, 1280), BG)
    px = im.load()
    for y in range(1280):
        t = y / 1280
        r = int(8 + 10 * (1 - t))
        g = int(10 + 14 * (1 - t))
        b = int(20 + 18 * (1 - t))
        for x in range(720):
            px[x, y] = (r, g, b, 255)
    d = ImageDraw.Draw(im)
    d.ellipse((480, 80, 620, 220), fill=(210, 216, 230, 255))
    d.polygon([(0, 860), (180, 700), (320, 900), (0, 1000)], fill=(18, 22, 34, 255))
    d.polygon([(200, 980), (420, 720), (700, 980), (720, 1100), (0, 1100)], fill=(12, 16, 26, 255))
    return im


def dao() -> Image.Image:
    im, d = icon_base(256)
    circle(d, (16, 16, 240, 240), None, GOLD, 6)
    circle(d, (48, 48, 208, 208), None, QI, 3)
    return im


def main() -> None:
    save(app_icon(192), "assets/icon.png")
    save(app_icon(512), "assets/icons/ui/icon_app_512.png")
    save(qi_orb(), "assets/icons/ui/icon_qi.png")
    save(background(), "assets/backgrounds/bg_mortal_night.png")
    save(silhouette(), "assets/characters/cultivator_silhouette.png")
    save(dao(), "assets/vfx/symbol_dao_circle.png")
    for name, col in {
        "aura_mortal": (140, 164, 190),
        "aura_qi": (92, 225, 255),
        "aura_foundation": (61, 219, 160),
        "aura_core": (240, 199, 94),
    }.items():
        save(aura(col), f"assets/vfx/{name}.png")
    for kind in ["cultivation", "upgrades", "ranks", "talents", "artifacts", "rebirth", "research"]:
        save(tab_icon(kind), f"assets/icons/tabs/{kind}.png")
    for kind in [
        "breath_meditation",
        "body_tempering",
        "meridian_opening",
        "spirit_sense",
        "qi_sea_expansion",
        "foundation_pill",
        "core_flame",
        "swift_circulation",
        "insight_scroll",
    ]:
        save(upgrade_icon(kind), f"assets/icons/upgrades/{kind}.png")
    # Simple chrome swatches so the art-direction paths exist. Live UI uses StyleBoxFlat.
    swatch = Image.new("RGBA", (64, 64), PANEL)
    ImageDraw.Draw(swatch).rounded_rectangle((2, 2, 61, 61), radius=10, outline=QI, width=2)
    save(swatch, "assets/ui/panel_9slice.png")
    jade_btn = Image.new("RGBA", (64, 64), (20, 50, 40, 255))
    ImageDraw.Draw(jade_btn).rounded_rectangle((2, 2, 61, 61), radius=10, outline=JADE, width=2)
    save(jade_btn, "assets/ui/button_jade.png")
    gold_btn = Image.new("RGBA", (64, 64), (50, 40, 16, 255))
    ImageDraw.Draw(gold_btn).rounded_rectangle((2, 2, 61, 61), radius=10, outline=GOLD, width=2)
    save(gold_btn, "assets/ui/button_gold.png")
    fill = Image.new("RGBA", (64, 16), QI)
    save(fill, "assets/ui/progress_fill.png")
    flash = Image.new("RGBA", (64, 64), (240, 199, 94, 90))
    save(flash, "assets/ui/breakthrough_flash.png")


if __name__ == "__main__":
    main()
