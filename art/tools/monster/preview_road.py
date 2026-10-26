#!/usr/bin/env python3
"""몬스터 걷기 시트를 흙길 위에 줄 세운 확인용 GIF (@2x 보드 크기)."""
import json, os
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
D = os.path.join(ROOT, "assets", "images", "monsters")
NAMES = ["mob-boar", "boss-boar", "mob-tiger", "boss-tiger", "mob-gumiho", "boss-gumiho"]


def load(name):
    meta = json.load(open(os.path.join(D, name, f"{name}-walk.json")))
    sheet = Image.open(os.path.join(D, name, f"{name}-walk.png"))
    frames = []
    for k in meta["animations"]["walk"]:
        f = meta["frames"][k]
        r = f["frame"]
        frames.append((sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])),
                       (f["anchor"]["x"] * r["w"], f["anchor"]["y"] * r["h"])))
    return frames


sets = [load(n) for n in NAMES]
W, H, road_y = 1560, 300, 210          # @2x 픽셀 (보드 780×150)
xs, x = [], 70
for fr in sets:
    w = max(im.width for im, _ in fr)
    xs.append(x + fr[0][1][0])
    x += w + 40
out = []
for i in range(6):
    bg = Image.new("RGBA", (W, H), (0xB9, 0xC5, 0x9E, 255))
    d = ImageDraw.Draw(bg)
    d.rectangle([0, road_y - 58, W, road_y + 58], fill=(0x7A, 0x64, 0x46, 255))
    d.rectangle([0, road_y - 50, W, road_y + 50], fill=(0xC3, 0xA6, 0x78, 255))
    d.rectangle([0, road_y - 30, W, road_y + 30], fill=(0xD2, 0xB8, 0x8C, 255))
    for fr, ax in zip(sets, xs):
        im, (axx, ayy) = fr[i % len(fr)]
        bg.alpha_composite(im, (round(ax - axx), round(road_y + 34 - ayy)))
    out.append(bg.convert("P", palette=Image.ADAPTIVE))
os.makedirs(os.path.join(ROOT, "art", "preview", "monsters"), exist_ok=True)
p = os.path.join(ROOT, "art", "preview", "monsters", "road-walk.gif")
out[0].save(p, save_all=True, append_images=out[1:], duration=100, loop=0)
out[0].convert("RGB").save(p.replace(".gif", ".png"))
print(p)
