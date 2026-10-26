"""병과 4등급 미리보기: 움직임 GIF, 맵 위 보드·폰 크기, 장수 공격 프레임."""
import json, os, sys
from PIL import Image, ImageDraw
b = sys.argv[1] if len(sys.argv) > 1 else "spear"
OUT = f"out2/{b}"
T = ["gunjol", "jeongbyeong", "gungwan", "jangsu"]
def load(t, a):
    m = json.load(open(f"{OUT}/unit-{b}-{t}-{a}.json")); s = Image.open(f"{OUT}/unit-{b}-{t}-{a}.png")
    return [(s.crop((v['frame']['x'], 0, v['frame']['x'] + v['frame']['w'], v['frame']['h'])), v) for v in m['frames'].values()]
D = {t: {a: load(t, a) for a in (("idle", "walk") if t != "jangsu" else ("idle", "attack"))} for t in T}
z, cw, ch = 1.5, 230, 180
frames = []
for t in range(24):
    c = Image.new("RGBA", (cw*4, ch*2), (185, 197, 158, 255))
    for j, tier in enumerate(T):
        for r, anim in enumerate(("idle", "attack" if tier == "jangsu" else "walk")):
            fr = D[tier][anim]; n = len(fr)
            idx = (t//3) % n if anim == "idle" else (t % n if anim == "attack" else (t//2) % n)
            im, v = fr[idx]; bb = im.resize((round(im.width*z), round(im.height*z)), Image.LANCZOS)
            c.alpha_composite(bb, (round(j*cw + cw*.42 - v['anchor']['x']*bb.width), round((r + 1)*ch - 8 - v['anchor']['y']*bb.height)))
    frames.append(c.convert("P", palette=Image.ADAPTIVE, colors=255))
frames[0].save(f"{OUT}/{b}-anim.gif", save_all=True, append_images=frames[1:], duration=83, loop=0, disposal=2)
m = Image.open("/home/claude/gmap/out/png/map-full.png").convert("RGBA").crop((440, 330, 1440, 760))
for j, tier in enumerate(T):
    im, v = D[tier]["idle"][0]
    m.alpha_composite(im, (round(120 + j*230 - v['anchor']['x']*im.width), round(330 - v['anchor']['y']*im.height)))
m = m.resize((m.width//2, m.height//2), Image.LANCZOS); m.save(f"{OUT}/{b}-on-map-board.png")
m.resize((round(m.width/1.85), round(m.height/1.85)), Image.LANCZOS).save(f"{OUT}/{b}-on-map-phone.png")
fr = D["jangsu"]["attack"]; w = fr[0][0].width
s = Image.new("RGBA", ((w + 10)*6 + 10, fr[0][0].height + 20), (244, 240, 230, 255)); d = ImageDraw.Draw(s)
for i, (im, v) in enumerate(fr):
    x = 10 + i*(w + 10); s.alpha_composite(im, (x, 10))
    for p in v.get("events", {}).values():
        d.ellipse((x + p['x'] - 6, 10 + p['y'] - 6, x + p['x'] + 6, 10 + p['y'] + 6), outline=(220, 40, 40, 255), width=3)
s.save(f"{OUT}/{b}-jangsu-attack-frames.png")
print("ok")
