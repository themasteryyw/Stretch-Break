#!/usr/bin/env python3
"""StretchBreak app icon — 'Reach'. Clean geometric figure, 4x render -> downsample."""
import os
from PIL import Image, ImageDraw, ImageFilter

SCALE = 4
S = 1024 * SCALE
def U(v): return int(round(v * SCALE))
WHITE = (248, 252, 251, 255)

# ---------- background: diagonal teal gradient + soft glow ----------
c = Image.new("RGB", (2, 2))
c.putpixel((0, 0), (0x1C, 0xCC, 0xBD))
c.putpixel((1, 0), (0x11, 0xB6, 0xAB))
c.putpixel((0, 1), (0x10, 0xAC, 0xA2))
c.putpixel((1, 1), (0x05, 0x79, 0x72))
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

# ---------- ground ----------
d.rounded_rectangle([U(304), U(864 + DY), U(720), U(884 + DY)], radius=U(10), fill=(255, 255, 255, 95))

# ---------- legs: near-parallel stand ----------
bone((512, 552 + DY), (452, 858 + DY), 64)
bone((512, 552 + DY), (572, 858 + DY), 64)

SHL, SHR = (470, 352 + DY), (554, 352 + DY)

# ---------- torso (from the middle of the shoulder bar) ----------
bone((512, 352 + DY), (512, 558 + DY), 84)

# ---------- shoulder bar ----------
bone(SHL, SHR, 78)

# ---------- arms rise from the shoulder ends (only two strokes ever meet) ----------
bone(SHL, (352, 206 + DY), 58)
bone(SHR, (672, 206 + DY), 58)

# ---------- neck + head (drawn last, stays crisp) ----------
bone((512, 300 + DY), (512, 352 + DY), 46)
dot(512, 214 + DY, 74)

# ---------- export ----------
out = img.convert("RGB").resize((1024, 1024), Image.LANCZOS)
dst = os.path.expanduser("~/Documents/StretchBreak/Sources/Assets.xcassets/AppIcon.appiconset")
os.makedirs(dst, exist_ok=True)
out.save(os.path.join(dst, "icon-1024.png"), "PNG")
out.save(os.path.expanduser("~/Desktop/StretchBreak-icon-preview.png"), "PNG")
print("wrote", os.path.join(dst, "icon-1024.png"))
