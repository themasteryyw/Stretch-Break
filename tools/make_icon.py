#!/usr/bin/env python3
import math
import os
from PIL import Image, ImageDraw

SCALE = 4
S = 1024 * SCALE
def U(v): return int(round(v * SCALE))
WHITE = (248, 252, 251, 255)

ASSETS = os.path.expanduser("~/Documents/StretchBreak/Sources/Assets.xcassets/AppIcon.appiconset")

BACKGROUND = (0x3C, 0x41, 0x38)

def bezier(p0, p1, p2, steps=64):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        pts.append((x, y))
    return pts

def render(size):
    img = Image.new("RGB", (S, S), BACKGROUND)
    d = ImageDraw.Draw(img)

    d.ellipse([U(512 - 92), U(230 - 92), U(512 + 92), U(230 + 92)], fill=WHITE)

    pts = bezier((512, 360), (760, 620), (512, 840))
    width = U(64)
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        d.line([(U(x1), U(y1)), (U(x2), U(y2))], fill=WHITE, width=width)
    r = width / 2
    for (x, y) in pts:
        d.ellipse([U(x) - r, U(y) - r, U(x) + r, U(y) + r], fill=WHITE)

    return img.resize((size, size), Image.LANCZOS)

os.makedirs(ASSETS, exist_ok=True)
icon = render(1024)
icon.save(os.path.join(ASSETS, "icon-1024.png"), "PNG")
icon.save(os.path.expanduser("~/Desktop/StretchBreak-icon-preview.png"), "PNG")
print("wrote", os.path.join(ASSETS, "icon-1024.png"))
