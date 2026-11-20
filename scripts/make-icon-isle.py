#!/usr/bin/env python3
"""灯り島のアイコン：夜の紫の海に浮かぶ小さな島と、琥珀色に光る灯台。1024×1024・透過なし。"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 2048
img = Image.new('RGB', (S, S), (0x1E, 0x13, 0x40))
d = ImageDraw.Draw(img)
# 上は深い夜、下は海（ターコイズが少し残る夕暮れ）
for y in range(S):
    k = y / S
    c = (int(0x16 + (0x2A - 0x16) * k), int(0x0D + (0x5A - 0x0D) * k ** 2), int(0x2B + (0x7E - 0x2B) * k ** 2))
    d.line([(0, y), (S, y)], fill=c)
# 灯台の光の帯
beam = Image.new('L', (S, S), 0)
bd = ImageDraw.Draw(beam)
top = (S * 0.58, S * 0.30)
bd.polygon([top, (S * 1.1, S * 0.05), (S * 1.1, S * 0.32)], fill=110)
bd.polygon([top, (-S * 0.1, S * 0.08), (-S * 0.1, S * 0.30)], fill=70)
beam = beam.filter(ImageFilter.GaussianBlur(30))
img = Image.composite(Image.new('RGB', (S, S), (0xFF, 0xC8, 0x72)), img, beam)
d = ImageDraw.Draw(img)
# 島
cx, cy = S * 0.5, S * 0.68
def isle(scale, lift=0):
    pts = []
    for i in range(120):
        a = i / 120 * 2 * math.pi
        r = 0.37 * (1 + 0.08 * math.sin(3 * a + 0.5) + 0.05 * math.cos(5 * a + 1.1)) * scale * S * 1.05
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.5 + lift))
    return pts
d.polygon(isle(1.18), fill=(0x5C, 0xCB, 0xC6))
d.polygon(isle(1.0, 40), fill=(0xC9, 0xA9, 0x7A))
d.polygon(isle(1.0), fill=(0xF8, 0xEF, 0xDF))
d.polygon(isle(0.76, -10), fill=(0x9C, 0xCB, 0x82))
# 灯台
bx, by = S * 0.58, S * 0.62
h = S * 0.30
w0, w1 = S * 0.075, S * 0.048
d.polygon([(bx - w0, by), (bx - w1, by - h), (bx + w1, by - h), (bx + w0, by)], fill=(0xFF, 0xFB, 0xF4))
for k in range(2):
    y0 = by - h * (0.22 + k * 0.36)
    y1 = y0 - h * 0.14
    t0 = w0 - (w0 - w1) * ((by - y0) / h)
    t1 = w0 - (w0 - w1) * ((by - y1) / h)
    d.polygon([(bx - t0, y0), (bx - t1, y1), (bx + t1, y1), (bx + t0, y0)], fill=(0xF5, 0x87, 0x6F))
glow = Image.new('L', (S, S), 0)
ImageDraw.Draw(glow).ellipse([bx - 260, by - h - 330, bx + 260, by - h + 190], fill=200)
glow = glow.filter(ImageFilter.GaussianBlur(90))
img = Image.composite(Image.new('RGB', (S, S), (0xFF, 0xC8, 0x72)), img, glow)
d = ImageDraw.Draw(img)
d.rounded_rectangle([bx - 62, by - h - 90, bx + 62, by - h], 18, fill=(0xFF, 0xE7, 0xA8))
d.polygon([(bx - 80, by - h - 90), (bx, by - h - 180), (bx + 80, by - h - 90)], fill=(0xF5, 0x87, 0x6F))
# たき火とヤシ
fx, fy = S * 0.38, S * 0.70
d.polygon([(fx - 46, fy), (fx, fy - 120), (fx + 46, fy)], fill=(0xFF, 0x9B, 0x4A))
d.polygon([(fx - 24, fy), (fx, fy - 70), (fx + 24, fy)], fill=(0xFF, 0xE0, 0x8A))
# もや（紫の小さなおばけ）
for (mx, my, r) in [(S * 0.15, S * 0.52, 70), (S * 0.86, S * 0.58, 60), (S * 0.22, S * 0.86, 54)]:
    d.ellipse([mx - r, my - r, mx + r, my + r], fill=(0x9A, 0x84, 0xE0))
    for k in (-1, 0, 1):
        d.ellipse([mx + k * r * 0.6 - r * 0.32, my + r * 0.75 - r * 0.32, mx + k * r * 0.6 + r * 0.32, my + r * 0.75 + r * 0.32], fill=(0x9A, 0x84, 0xE0))
    for k in (-1, 1):
        d.ellipse([mx + k * r * 0.32 - 12, my - 22, mx + k * r * 0.32 + 12, my + 2], fill=(0xFF, 0xC8, 0x72))
# 星
for (sx, sy) in [(0.12, 0.12), (0.3, 0.2), (0.8, 0.42), (0.45, 0.1), (0.9, 0.12)]:
    d.ellipse([S * sx - 8, S * sy - 8, S * sx + 8, S * sy + 8], fill=(0xF5, 0xEE, 0xFF))
out = os.path.join(os.path.dirname(__file__), '..', 'App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png')
img.resize((1024, 1024), Image.LANCZOS).save(out)
print('saved', out)
