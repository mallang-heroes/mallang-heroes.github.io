#!/usr/bin/env python3
"""병과 라인업(A) + 장수 포즈(B) → 기본 슬라임 4등급 스프라이트.

사용: python3 process_branch.py <branch> [--pad-color R,G,B]
입력: src2/<branch>-A.png (군졸·정병·군관·장수), src2/<branch>-B.png (장수 기본·눈 감음·공격)
그림 한 장 전체를 말랑하게 변형해 대기·걷기·공격을 만든다.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from keying import key_out
from split_units import split_characters

H = os.path.dirname(os.path.abspath(__file__))
SCALE = 2
TARGET = {"gunjol": 46, "jeongbyeong": 54, "gungwan": 60, "jangsu": 66}   # 몸+머리쓰개 높이 (보드 px)
TARGET_RIDER = {"gunjol": 64, "jeongbyeong": 70, "gungwan": 76, "jangsu": 82}  # 기병: 말+기수 전체 높이
BRANCH_COL = {"spear": (154, 59, 46), "archer": (63, 107, 58), "gunner": (94, 78, 140),
              "cavalry": (138, 100, 24), "navy": (46, 94, 140), "mystic": (74, 78, 84)}


def clean_edges(img, border=3):
    a = np.asarray(img).copy()
    a[:border, :, 3] = a[-border:, :, 3] = 0
    a[:, :border, 3] = a[:, -border:, 3] = 0
    return Image.fromarray(a, "RGBA")


def remove_sparkle(img, src_rgb=None):
    """오른쪽 아래 제미나이 워터마크(반짝이)를 주변 색·투명도로 덮음 (캐릭터 위든 배경 위든)."""
    a = np.asarray(img).copy()
    Hh, W = a.shape[:2]
    y0, y1, x0, x1 = int(Hh*.76), int(Hh*.94), int(W*.86), int(W*.96)
    sub = a[y0:y1, x0:x1].astype(np.float32)
    al = sub[..., 3] / 255
    rgb = sub[..., :3] * al[..., None] + 255 * (1 - al[..., None]) * np.array([1, 0, 1])   # 마젠타 위에 다시 합성해 본 색
    lum = rgb.mean(2)
    sat = rgb.max(2) - rgb.min(2)
    med_l = ndimage.median_filter(lum, 41)
    # 반짝이: 주변보다 밝고, 채도가 낮은 하얀빛
    star = (lum > med_l + 14) & (sat < 150) & (rgb.min(2) > 150)
    star = ndimage.binary_dilation(star, iterations=3)
    if star.any():
        for c in range(4):
            med = ndimage.median_filter(np.where(star, np.nan, sub[..., c]), 31) if False else ndimage.grey_dilation(sub[..., c], 1)
        # 주변(반짝이 바깥) 값으로 안쪽을 채움
        _, (iy, ix) = ndimage.distance_transform_edt(star, return_indices=True)
        sub = sub[iy, ix]
        a[y0:y1, x0:x1] = sub.astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def helmet_width(img):
    a = np.asarray(img).astype(np.int32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    steel = (al > 200) & (b >= r) & (b > g - 8) & (mx - mn < 60) & (mx > 80) & (mx < 210)
    steel = ndimage.binary_opening(steel, iterations=2)
    lab, n = ndimage.label(steel)
    if n == 0:
        return None
    sizes = ndimage.sum(steel, lab, range(1, n + 1))
    ys, xs = np.where(lab == (int(np.argmax(sizes)) + 1))
    return xs.max() - xs.min()


def keep_main(img):
    """가장 큰 덩어리만 남김 (자르지 않아서 위치가 그대로 유지됨)."""
    a = np.asarray(img).copy()
    m = a[..., 3] > 20
    lab, n = ndimage.label(ndimage.binary_dilation(m, iterations=3))
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    keep = lab == (int(np.argmax(sizes)) + 1)
    a[..., 3] = np.where(keep, a[..., 3], 0)
    return Image.fromarray(a, "RGBA")


def core_box(img, it=9):
    """창·상모처럼 얇은 것을 뺀 몸+머리쓰개 영역 (높이·발밑 기준)."""
    m = np.asarray(img)[..., 3] > 128
    core = ndimage.binary_opening(m, iterations=it)
    lab, n = ndimage.label(core)
    sizes = ndimage.sum(core, lab, range(1, n + 1))
    core = lab == (int(np.argmax(sizes)) + 1)
    ys, xs = np.where(core)
    bottom = ys.max()
    foot_x = xs[ys > bottom - (bottom - ys.min()) * .12].mean()
    low = ys > bottom - (bottom - ys.min()) * .25          # 몸 아래쪽 (무기 제외) 폭
    core_box.width = xs[low].max() - xs[low].min()
    return ys.min(), bottom, foot_x


def place(canvas, img, pivot, pos, ang=0.0, sx=1.0, sy=1.0):
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    px, py = pos
    data = (c/sx, s/sx, pivot[0] - (c*px + s*py)/sx, -s/sy, c/sy, pivot[1] - (-s*px + c*py)/sy)
    t = img.convert("RGBa").transform(canvas.size, Image.AFFINE, data, resample=Image.BICUBIC).convert("RGBA")
    canvas.alpha_composite(t)


class Sprite:
    """잘라 낸 그림 + 발밑 점 + 몸 높이 → 보드 크기로 맞춘 그림.
    like=다른 Sprite를 주면 같은 배율을 쓰고(같은 그림 크기로 그려진 포즈), same_pos=True면 발밑 점까지 같게 (같은 자리에 그려진 눈 감은 그림)."""
    def __init__(self, img, target_h, like=None, same_pos=False):
        top, bottom, fx = core_box(img)
        if like is None:
            k = target_h * SCALE * 3 / (bottom - top)       # 3배로 만들어 두고 마지막에 줄임 (변형 품질)
        else:
            k = like.k
        self.img = img.resize((round(img.width*k), round(img.height*k)), Image.LANCZOS)
        self.foot = like.foot if (like is not None and same_pos) else (fx*k, bottom*k)
        self.k = k
        self.core_w = core_box.width * k


def frame(sprite, pose, canvas, foot):
    sx, sy = pose.get("squash", (1, 1))
    lift = pose.get("lift", 0) * SCALE * 3
    shift = pose.get("shift", 0) * SCALE * 3
    c = Image.new("RGBA", canvas)
    # 땅 그림자 (뛰면 작아짐)
    sh = Image.new("RGBA", canvas)
    d = ImageDraw.Draw(sh)
    rx = sprite.core_w * .42 * (1 - min(lift, 60) / 160)
    d.ellipse((foot[0] - rx, foot[1] - rx*.16, foot[0] + rx, foot[1] + rx*.16), fill=(25, 35, 15, 80))
    c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    if pose.get("pad"):
        d = ImageDraw.Draw(c)
        col = pose["pad"]
        rx, ry = 21*SCALE*3, 4.8*SCALE*3
        d.ellipse((foot[0] - rx, foot[1] - ry, foot[0] + rx, foot[1] + ry), fill=col + (120,), outline=col + (255,), width=9)
    place(c, sprite.img, sprite.foot, (foot[0] + shift, foot[1] - lift), pose.get("lean", 0), sx, sy)
    return c


IDLE = [dict(), dict(squash=(1.025, .975)), dict(squash=(1.045, .955), blink=True), dict(squash=(1.02, .98))]
WALK = [dict(squash=(1.10, .90)), dict(squash=(.92, 1.10), lift=5), dict(lift=8), dict(squash=(1.06, .94), lift=1.5)]
ATTACK = [dict(), dict(squash=(1.08, .92), lean=-5, shift=-2), dict(squash=(1.12, .88), lean=-8, shift=-3),
          dict(squash=(.96, 1.04), lean=1, shift=3, pose="attack"), dict(squash=(.98, 1.02), lean=2, shift=4, pose="attack"),
          dict(squash=(1.02, .98), lean=2, shift=1)]


def export(branch, tier, sprites, anims, out, pad=None):
    name = f"unit-{branch}-{tier}"
    res = {}
    for anim, (poses, fps) in anims.items():
        big = (sprites["base"].img.width*3, sprites["base"].img.height*3)
        foot = (big[0]/2, big[1]*.8)
        frames = []
        for p in poses:
            key = "attack" if p.get("pose") == "attack" else ("blink" if p.get("blink") and "blink" in sprites else "base")
            pp = dict(p)
            if pad:
                pp["pad"] = pad
            frames.append(frame(sprites[key], pp, big, foot))
        boxes = [f.getbbox() for f in frames]
        x0, y0 = min(b[0] for b in boxes) - 6, min(b[1] for b in boxes) - 6
        x1, y1 = max(b[2] for b in boxes) + 6, foot[1] + 4*SCALE*3
        # 보드 정수 크기
        Wb, Hb = math.ceil((x1 - x0) / (SCALE*3)), math.ceil((y1 - y0) / (SCALE*3))
        x1, y1 = x0 + Wb*SCALE*3, y0 + Hb*SCALE*3
        cells, fr = [], {}
        Wp, Hp = Wb*SCALE, Hb*SCALE
        for i, f in enumerate(frames):
            cell = f.crop((round(x0), round(y0), round(x1), round(y1))).resize((Wp, Hp), Image.LANCZOS)
            cells.append(cell)
            k = f"{name}-{anim}-{i}"
            fr[k] = {"frame": {"x": i*Wp, "y": 0, "w": Wp, "h": Hp}, "duration": round(1000/fps),
                     "anchor": {"x": round((foot[0] - x0)/(x1 - x0), 4), "y": round((foot[1] - y0)/(y1 - y0), 4)}}
            if anim == "attack" and i == 3 and "attack" in sprites:
                s = sprites["attack"]
                a = np.asarray(s.img)[..., 3] > 128
                ys, xs = np.where(a[: int(s.foot[1]*.75)])
                tx, ty = xs.max(), ys[xs == xs.max()].mean()       # 무기 끝 (가장 오른쪽 점)
                p = ATTACK[3]
                # 프레임 변형을 근사 적용
                dx, dy = (tx - s.foot[0]) * p["squash"][0], (ty - s.foot[1]) * p["squash"][1]
                r = math.radians(p["lean"])
                X = foot[0] + p["shift"]*SCALE*3 + dx*math.cos(r) - dy*math.sin(r)
                Y = foot[1] + dx*math.sin(r) + dy*math.cos(r)
                fr[k]["events"] = {("projectile" if branch in ("archer", "gunner", "mystic") else "hit"): {"x": round((X - x0) / (SCALE*3) * SCALE, 1), "y": round((Y - y0) / (SCALE*3) * SCALE, 1)}}
        sheet = Image.new("RGBA", (Wp*len(cells), Hp))
        for i, c in enumerate(cells):
            sheet.paste(c, (i*Wp, 0))
        sheet.save(os.path.join(out, f"{name}-{anim}.png"))
        json.dump({"frames": fr, "animations": {anim: list(fr)},
                   "meta": {"image": f"{name}-{anim}.png", "size": {"w": sheet.width, "h": Hp}, "scale": str(SCALE), "fps": fps,
                            "board_frame": {"w": Wb, "h": Hb}, "body_height": (TARGET_RIDER if branch == "cavalry" else TARGET)[tier],
                            "note": "그림 한 장 전체 변형. anchor = 몸 바닥 가운데. 좌우 반전 시 x' = w - x."}},
                  open(os.path.join(out, f"{name}-{anim}.json"), "w"), ensure_ascii=False, indent=1)
        if anim == "idle":
            cells[0].save(os.path.join(out, f"{name}.png"))
        res[anim] = (cells, fr)
    return res


def main(branch):
    src = os.path.join(H, "src2")
    out = os.path.join(H, "out2", branch)
    os.makedirs(out, exist_ok=True)
    tiers = ["gunjol", "jeongbyeong", "gungwan", "jangsu"]
    per_tier = [os.path.join(src, f"{branch}-T{i}.png") for i in range(1, 5)]
    if all(os.path.exists(p) for p in per_tier):          # 등급마다 한 장씩 받은 경우 (기병)
        imgs = {t: split_characters(clean_edges(key_out(p)), 1)[0][1] for t, p in zip(tiers, per_tier)}
        a = None
    else:
        A = clean_edges(remove_sparkle(key_out(os.path.join(src, f"{branch}-A.png")), None))
        a = split_characters(A, 4)
        imgs = {t: im for t, (_, im) in zip(tiers, a)}
    TGT = TARGET_RIDER if branch == "cavalry" else TARGET
    combined = os.path.join(src, f"{branch}-B.png")      # 예전 방식(세 포즈 한 장)이 있으면 씀
    b = None
    if os.path.exists(combined):
        B = clean_edges(remove_sparkle(key_out(combined), None))
        b = split_characters(B, 3)
        b_base, b_blink, b_attack = (im for _, im in b)
        imgs["jangsu"] = b_base
    # 장수 한 마리 입력 그림으로 따로 받은 눈 감음(B1)·공격(B2)이 있으면 그것을 씀
    inp, b1, b2 = (os.path.join(src, f"{branch}-{n}.png") for n in ("jangsu-input", "B1", "B2"))
    if not os.path.exists(inp) and os.path.exists(os.path.join(src, f"{branch}-T4.png")):
        inp = os.path.join(src, f"{branch}-T4.png")
    single = os.path.exists(inp) and os.path.exists(b1) and os.path.exists(b2)
    if single:
        J_base = keep_main(clean_edges(key_out(inp)))
        J_blink = keep_main(clean_edges(remove_sparkle(key_out(b1), None)))
        J_attack = split_characters(clean_edges(remove_sparkle(key_out(b2), None)), 1)[0][1]
    # B 2번이 장수인지 군관인지 판단: 크기·위치가 A 군관과 거의 같으면 군관 깜빡임으로 씀
    blink_for = {}
    if b is not None and a is not None:
        ga = a[2][0]; gb = b[1][0]
        if abs(ga[0] - gb[0]) < 12 and abs(ga[1] - gb[1]) < 12 and abs(ga[2] - gb[2]) < 12:
            blink_for["gungwan"] = b_blink
        else:
            blink_for["jangsu"] = b_blink
    res = {}
    for t in tiers:
        sp = {"base": Sprite(imgs[t], TGT[t])}
        if t in blink_for:
            sp["blink"] = Sprite(blink_for[t], TGT[t])
        if t == "jangsu" and single:
            sp = {"base": Sprite(J_base, TGT[t])}
            sp["blink"] = Sprite(J_blink, TGT[t], like=sp["base"], same_pos=True)
            sp["attack"] = Sprite(J_attack, TGT[t], like=sp["base"])
            hb, ha = helmet_width(J_base), helmet_width(J_attack)
            hh = J_base.getbbox(); ha_h = J_attack.height
            same_height = abs((hh[3] - hh[1]) / ha_h - 1) < .12      # 그림 전체 높이가 비슷하면 같은 크기로 그린 것
            if hb and ha and abs(ha / hb - 1) > .06 and not same_height:      # 공격 그림이 다른 크기로 그려졌으면 투구 폭으로 맞춤
                class _L: pass
                ref = _L(); ref.k = sp["base"].k * hb / ha; ref.foot = None
                sp["attack"] = Sprite(J_attack, TGT[t], like=ref)
                print("attack rescale", round(hb / ha, 3))
            sp["attack"].core_w = sp["base"].core_w           # 그림자 크기는 기본 자세 기준
            blink_for["jangsu"] = J_blink
        elif t == "jangsu" and b is not None:
            sp["attack"] = Sprite(b_attack, TGT[t])
        elif t == "jangsu":                                  # 공격 그림이 아직 없으면 기본 그림으로 임시 공격
            sp["attack"] = sp["base"]
        if t == "jangsu":
            anims = {"idle": (IDLE, 6), "attack": (ATTACK, 12)}
            res[t] = export(branch, t, sp, anims, out, pad=BRANCH_COL[branch])
        else:
            res[t] = export(branch, t, sp, {"idle": (IDLE, 6), "walk": (WALK, 10)}, out)
    print(branch, {t: res[t]["idle"][0][0].size for t in tiers}, "blink:", list(blink_for))
    return res


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "spear")
