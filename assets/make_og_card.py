#!/usr/bin/env python3
"""
Generate the BurnReward Open Graph share card (1200x630).

Renders an 8-bit / pixel-art card matching the site's dark neon theme so that
links to the landing page show a branded preview on iMessage, Twitter, etc.

Usage:  python3 assets/make_og_card.py
Output: og-card.png  (repo root)
"""
import os
from PIL import Image, ImageDraw, ImageFont

# ── Canvas ────────────────────────────────────────────────────────────
W, H = 1200, 630
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "PressStart2P.ttf")
OUT  = os.path.join(HERE, "..", "og-card.png")

# ── Palette (dark theme) ──────────────────────────────────────────────
BG      = (10, 10, 20)
GRID    = (0, 255, 136, 10)
GREEN   = (0, 255, 136)
GREEN_D = (0, 119, 68)
YELLOW  = (255, 215, 0)
ORANGE  = (255, 107, 53)
RED     = (255, 34, 68)
BLUE    = (0, 170, 255)
PURPLE  = (204, 68, 255)
TEXT    = (232, 232, 255)
MUTED   = (110, 110, 170)
CARD    = (17, 17, 32)
BORDER  = (42, 42, 68)

img  = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img, "RGBA")

def font(sz):
    return ImageFont.truetype(FONT, sz)

def center(draw, text, fnt, y, fill, shadow=None, soff=4):
    w = draw.textlength(text, font=fnt)
    x = (W - w) / 2
    if shadow:
        draw.text((x + soff, y + soff), text, font=fnt, fill=shadow)
    draw.text((x, y), text, font=fnt, fill=fill)
    return x, w

# ── Background dot grid (dark-theme pattern) ──────────────────────────
for gy in range(0, H, 24):
    for gx in range(0, W, 24):
        draw.point((gx, gy), fill=GRID)

# ── Rainbow top bar ───────────────────────────────────────────────────
bar = [GREEN, YELLOW, ORANGE, RED, PURPLE, BLUE]
seg = W / len(bar)
for i, c in enumerate(bar):
    draw.rectangle([i * seg, 0, (i + 1) * seg, 8], fill=c)

# ── Corner brackets (neon green) ──────────────────────────────────────
L, T = 3, 40   # thickness, arm length offset
arm  = 46
for (cx, cy, dx, dy) in [(34, 34, 1, 1), (W-34, 34, -1, 1),
                         (34, H-34, 1, -1), (W-34, H-34, -1, -1)]:
    draw.rectangle(sorted([cx, cx + dx*arm]) + [cy, cy + dy*3] if False else
                   [min(cx, cx+dx*arm), min(cy, cy+dy*3),
                    max(cx, cx+dx*arm), max(cy, cy+dy*3)], fill=GREEN)
    draw.rectangle([min(cx, cx+dx*3), min(cy, cy+dy*arm),
                    max(cx, cx+dx*3), max(cy, cy+dy*arm)], fill=GREEN)

# ── INSERT COIN (blinking line, static here) ─────────────────────────
center(draw, "* INSERT COIN TO START *", font(15), 70, YELLOW)

# ── LVL badge ─────────────────────────────────────────────────────────
badge = "LVL 1 FITNESS RPG"
bf    = font(13)
bw    = draw.textlength(badge, font=bf)
bx, by, bpx, bpy = (W - bw)/2, 108, 18, 12
draw.rectangle([bx-bpx, by-bpy, bx+bw+bpx, by+22+bpy], fill=CARD, outline=YELLOW, width=2)
draw.text((bx, by), badge, font=bf, fill=YELLOW)

# ── BURNREWARD logo with neon glow ───────────────────────────────────
logo  = "BURNREWARD"
lf    = font(72)
lw    = draw.textlength(logo, font=lf)
lx, ly = (W - lw)/2, 188
# glow: a subtle tight halo so the letters stay crisp
for r in (6, 4, 2):
    a = int(34 * (r / 6))
    for ox, oy in [(-r,0),(r,0),(0,-r),(0,r)]:
        draw.text((lx+ox, ly+oy), logo, font=lf, fill=(0, 255, 136, a))
draw.text((lx+5, ly+5), logo, font=lf, fill=GREEN_D)   # drop shadow
draw.text((lx, ly), logo, font=lf, fill=GREEN)
# blinking cursor block
draw.rectangle([lx+lw+10, ly+8, lx+lw+10+44, ly+60], fill=GREEN)

# ── Tagline ───────────────────────────────────────────────────────────
center(draw, "SWEAT NOW.  FEAST LATER.", font(24), 300, YELLOW, shadow=(110,90,0), soff=3)

# ── EXP bar (on-brand progress visual) ───────────────────────────────
ebw, ebh = 620, 38
ebx, eby = (W - ebw)/2, 372
draw.text((ebx, eby-26), "EXP", font=font(13), fill=YELLOW)
draw.text((ebx+ebw-58, eby-26), "78%", font=font(15), fill=GREEN)
draw.rectangle([ebx, eby, ebx+ebw, eby+ebh], fill=(8,8,8), outline=YELLOW, width=3)
fill_w = int(ebw * 0.78)
for fx in range(int(ebx)+3, int(ebx)+fill_w, 14):
    draw.rectangle([fx, eby+3, fx+9, eby+ebh-3], fill=YELLOW)

# ── Reward chips (pixel food cards) ──────────────────────────────────
chips = [("BURRITO", ORANGE), ("PIZZA", RED), ("SUNDAE", BLUE), ("DONUT", PURPLE)]
cf    = font(11)
cw, ch, gap = 132, 44, 18
total = len(chips)*cw + (len(chips)-1)*gap
sx    = (W - total)/2
cy    = 452
for i, (label, col) in enumerate(chips):
    x = sx + i*(cw+gap)
    draw.rectangle([x, cy, x+cw, cy+ch], fill=CARD, outline=col, width=2)
    tw = draw.textlength(label, font=cf)
    draw.text((x+(cw-tw)/2, cy+16), label, font=cf, fill=col)

# ── Bottom strip ──────────────────────────────────────────────────────
center(draw, "EARN YOUR TREATS  *  COMING TO APPLE WATCH", font(15), 548, GREEN)
center(draw, "APP STORE  >  v0.1.0", font(11), 586, MUTED)

# ── Global scanlines ──────────────────────────────────────────────────
scan = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd   = ImageDraw.Draw(scan)
for y in range(0, H, 4):
    sd.line([(0, y), (W, y)], fill=(0, 0, 0, 28), width=1)
img = Image.alpha_composite(img.convert("RGBA"), scan).convert("RGB")

img.save(OUT)
print(f"Wrote {os.path.normpath(OUT)} ({W}x{H})")
