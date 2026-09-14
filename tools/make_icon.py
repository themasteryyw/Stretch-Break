#!/usr/bin/env python3
"""StretchBreak app icons — 'Reach'. Clean geometric figure, 4x render -> downsample.

Generates the primary icon plus every alternate (theme) icon from the same
figure geometry, so switching AppTheme in-app always shows a matching icon.
Alt-icon base colors are pulled straight from real Pantone Colors of the Year
(kept in sync with AppTheme.color in Sources/Views.swift):
  - Peach Fuzz   (Pantone 13-1023, COTY 2024) -> "blush" theme
  - Mocha Mousse (Pantone 17-1230, COTY 2025) -> "latte" theme
"""
import os
from PIL import Image, ImageDraw, ImageFilter

SCALE = 4
S = 1024 * SCALE
def U(v): return int(round(v * SCALE))
WHITE = (248, 252, 251, 255)

ROOT = os.path.expanduser("~/Documents/StretchBreak")
ASSETS = os.path.join(ROOT, "Sources/Assets.xcassets/AppIcon.appiconset")
ALT = os.path.join(ROOT, "Sources/AltIcons")


def lighten(rgb, amt):
    return tuple(int(round(c + (255 - c) * amt)) for c in rgb)


def darken(rgb, amt):
    return tuple(int(round(c * (1 - amt))) for c in rgb)


def render(corner_tl, corner_tr, corner_bl, corner_br, size):
    """Draws the 'Reach' figure over a diagonal gradient, returns a `size`x`size` RGB image."""
    c = Image.new("RGB", (2, 2))
    c.putpixel((0, 0), corner_tl)
    c.putpixel((1, 0), corner_tr)
    c.putpixel((0, 1), corner_bl)
    c.putpixel((1, 1), corner_br)
    img = c.resize((S, S), Image.BILINEAR).convert("RGBA")
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([U(-280), U(-340), U(560), U(360)], fill=(255, 255, 255, 34))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(U(130))))
    d = ImageDraw.Draw(img)

    def dot(cx, cy, r, fill=WHITE):
        d.ellipse([U(cx - r), U(cy - r), U(cx + r), U(cy + r)], fill=fill)

    def bone(p1, p2, w, fill=WHITE):
        d.line([(U(p1[0]), U(p1[1])), (U(p2[0]), U(p2[1]))], fill=fill, width=U(w))
        dot(*p1, w / 2, fill); dot(*p2, w / 2, fill)

    DY = 6   # nudge the whole figure down for even margins

    d.rounded_rectangle([U(304), U(864 + DY), U(720), U(884 + DY)], radius=U(10), fill=(255, 255, 255, 95))

    bone((512, 552 + DY), (452, 858 + DY), 64)
    bone((512, 552 + DY), (572, 858 + DY), 64)

    SHL, SHR = (470, 352 + DY), (554, 352 + DY)
    bone((512, 352 + DY), (512, 558 + DY), 84)
    bone(SHL, SHR, 78)
    bone(SHL, (352, 206 + DY), 58)
    bone(SHR, (672, 206 + DY), 58)
    bone((512, 300 + DY), (512, 352 + DY), 46)
    dot(512, 214 + DY, 74)

    return img.convert("RGB").resize((size, size), Image.LANCZOS)


# ---------- primary (teal) ----------
primary = render((0x1C, 0xCC, 0xBD), (0x11, 0xB6, 0xAB), (0x10, 0xAC, 0xA2), (0x05, 0x79, 0x72), 1024)
os.makedirs(ASSETS, exist_ok=True)
primary.save(os.path.join(ASSETS, "icon-1024.png"), "PNG")
primary.save(os.path.expanduser("~/Desktop/StretchBreak-icon-preview.png"), "PNG")
print("wrote", os.path.join(ASSETS, "icon-1024.png"))

# ---------- alternates, from real Pantone Colors of the Year ----------
PEACH_FUZZ = (0xFF, 0xBE, 0x98)     # Pantone 13-1023, COTY 2024
MOCHA_MOUSSE = (0xA4, 0x77, 0x64)   # Pantone 17-1230, COTY 2025

ALTERNATES = {
    "Pink": PEACH_FUZZ,      # AppTheme.blush
    "Latte": MOCHA_MOUSSE,   # AppTheme.latte
}

os.makedirs(ALT, exist_ok=True)
for name, base in ALTERNATES.items():
    tl = lighten(base, 0.28)
    br = darken(base, 0.18)
    for scale, size in (("@2x", 120), ("@3x", 180)):
        img = render(tl, base, base, br, size)
        path = os.path.join(ALT, f"AppIcon-{name}{scale}.png")
        img.save(path, "PNG")
        print("wrote", path)
