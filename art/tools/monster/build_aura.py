#!/usr/bin/env python3
"""좀비가 된 왕 둘레의 보라·남색 기운 (코드로 그림). 왕 뒤에 깔아 그린다.

출력: assets/images/monsters/boss-zombie-king/boss-zombie-king-aura.{png,json}
4프레임 6fps 반복. 앵커는 왕 발밑과 같은 점이라 왕과 같은 자리에 그리면 된다.
제미나이로 기운 시트를 받으면 이 스크립트 대신 그 그림으로 바꿔도 된다.
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
D = os.path.join(ROOT, "assets", "images", "monsters", "boss-zombie-king")
NAME = "boss-zombie-king-aura"
W, H = 300, 260            # @2x 프레임
FOOT = (150, 236)          # 발밑 (@2x)
BODY_H = 190               # 몸 높이 (@2x, 96×100 프레임 기준 몸통 부분)
COLS = [(46, 30, 92), (78, 44, 140), (112, 70, 178), (64, 52, 128)]


def frame(i, n=4):
    rng = np.random.default_rng(11)
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    cx, cy = FOOT[0], FOOT[1] - BODY_H * 0.48
    ph = 2 * math.pi * i / n
    # 몸 둘레를 도는 연기 덩어리
    for k in range(26):
        a = 2 * math.pi * k / 26 + ph * 0.25
        rx, ry = 106 + 10 * math.sin(3 * a + ph), 104 + 8 * math.cos(2 * a - ph)
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry * 0.95
        r = 20 + 9 * math.sin(a * 2 + ph + rng.random())
        c = COLS[k % len(COLS)]
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (int(175 + 60 * math.sin(a + ph)),))
    # 위로 피어오르는 김
    for k in range(5):
        x = cx - 90 + k * 45 + 8 * math.sin(ph + k)
        y = cy - 70 - ((i + k) % n) * 22
        r = 14 - ((i + k) % n) * 2.5
        d.ellipse([x - r, y - r, x + r, y + r], fill=COLS[1] + (int(150 - ((i + k) % n) * 30),))
    im = im.filter(ImageFilter.GaussianBlur(3))
    # 가운데(몸)는 비움: 몸 뒤에 깔리지만 몸 밖으로 번지는 부분만 보이게 부드럽게 뚫음
    a = np.asarray(im).astype(np.float32)
    yy, xx = np.mgrid[:H, :W]
    dist = np.sqrt(((xx - cx) / 92) ** 2 + ((yy - cy) / 96) ** 2)
    a[..., 3] *= np.clip((dist - 0.55) / 0.35, 0, 1)
    # 반짝이는 불씨 하나
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(out)
    ex, ey = cx + 96 * math.cos(ph + 0.6), cy - 40 + 60 * math.sin(ph + 0.6)
    d.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=(196, 150, 255, 230))
    d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=(250, 236, 255, 255))
    return out


frames = [frame(i) for i in range(4)]
sheet = Image.new("RGBA", (W * 4, H))
meta = {"frames": {}, "animations": {"aura": []},
        "meta": {"image": f"{NAME}.png", "size": {"w": W * 4, "h": H}, "scale": "2", "fps": 6, "loop": True,
                 "note": "왕 뒤에 깔아 그리는 기운. anchor = 왕 발밑과 같은 점"}}
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * W, 0))
    k = f"{NAME}-{i}"
    meta["frames"][k] = {"frame": {"x": i * W, "y": 0, "w": W, "h": H}, "duration": 167,
                         "anchor": {"x": round(FOOT[0] / W, 4), "y": round(FOOT[1] / H, 4)}}
    meta["animations"]["aura"].append(k)
os.makedirs(D, exist_ok=True)
sheet.save(os.path.join(D, f"{NAME}.png"), optimize=True)
json.dump(meta, open(os.path.join(D, f"{NAME}.json"), "w"), ensure_ascii=False, indent=1)
print("aura ok")
