#!/usr/bin/env python3
"""리깅 결과 확인용 미리보기: 움직임 GIF, 공격 프레임 + 타격점, 맵 위 보드·폰 크기."""
import json, os, sys
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", sys.argv[1] if len(sys.argv) > 1 else "spear-jangsu")
NAME = sys.argv[2] if len(sys.argv) > 2 else "unit-spear-jangsu"
MAP = "/home/claude/map/preview/map-preview-board.png"


def load(anim):
    meta = json.load(open(os.path.join(OUT, f"{NAME}-{anim}.json")))
    sheet = Image.open(os.path.join(OUT, f"{NAME}-{anim}.png"))
    frames = []
    for k, v in meta["frames"].items():
        f = v["frame"]
        frames.append((sheet.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])), v))
    return frames, meta["meta"]["fps"]

att, _ = load("attack")
idl, _ = load("idle")
z = 2
W = max(f.width for f, _ in att) * z // 2 * 2 + 40
H = max(f.height for f, _ in att) * z
gif = []
for t in range(24):
    c = Image.new("RGBA", (W*2, H + 20), (185, 197, 158, 255))
    for col, (frs, i) in enumerate(((att, t % 6), (idl, (t // 6) % 4))):
        im, v = frs[i]
        big = im.resize((im.width*z//2*2 // 2 * 1, im.height*z//2*2 // 2), Image.LANCZOS) if False else im.resize((im.width*z//2, im.height*z//2), Image.LANCZOS)
        big = im.resize((round(im.width*1.5), round(im.height*1.5)), Image.LANCZOS)
        ax = v["anchor"]["x"]*big.width
        c.alpha_composite(big, (round(col*W + W/2 - ax), H + 10 - big.height))
    gif.append(c.convert("P", palette=Image.ADAPTIVE, colors=255))
gif[0].save(os.path.join(OUT, f"{NAME}-anim.gif"), save_all=True, append_images=gif[1:], duration=83, loop=0, disposal=2)

# 공격 프레임 + 타격점
fw = max(f.width for f, _ in att)
s = Image.new("RGBA", ((fw + 10)*6 + 10, att[0][0].height + 20), (244, 240, 230, 255))
d = ImageDraw.Draw(s)
for i, (im, v) in enumerate(att):
    x = 10 + i*(fw + 10)
    s.alpha_composite(im, (x, 10))
    for p in v.get("events", {}).values():
        cx, cy = x + p["x"], 10 + p["y"]
        d.ellipse((cx-6, cy-6, cx+6, cy+6), outline=(220, 40, 40, 255), width=3)
s.save(os.path.join(OUT, f"{NAME}-attack-frames.png"))

# 맵 위 (보드 크기 = @2x 의 절반)
m = Image.open(MAP).convert("RGBA").crop((180, 160, 620, 340))
for j, (frs, i, gx) in enumerate(((idl, 0, 90), (att, 3, 270))):
    im, v = frs[i]
    b = im.resize((im.width//2, im.height//2), Image.LANCZOS)
    m.alpha_composite(b, (round(gx - v["anchor"]["x"]*b.width), round(150 - v["anchor"]["y"]*b.height)))
m.save(os.path.join(OUT, f"{NAME}-on-map-board.png"))
m.resize((round(m.width/1.85), round(m.height/1.85)), Image.LANCZOS).save(os.path.join(OUT, f"{NAME}-on-map-phone.png"))
print("ok")
