#!/usr/bin/env python3
"""제미나이 파츠 → 컷아웃 리깅 → 대기 4 / 공격 6 프레임 (창병 장수, 귀여운 콘셉트).

좌표는 파츠 시트 원본 픽셀(이하 '원본'). 마지막에 보드 크기 @2x로 줄인다.
"""
import json, math, os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
PD = os.path.join(ROOT, "parts", "spear-jangsu")
OUT = os.path.join(ROOT, "out", "spear-jangsu")
os.makedirs(OUT, exist_ok=True)

L = lambda k: Image.open(os.path.join(PD, f"part-{k:02d}.png")).convert("RGBA")

# ------------------------------------------------------------------ 파츠 준비
CUT = 297                                      # 눈 감은 머리 + 몸통 분리선 (part-01 안 y)
p1 = L(1)
HEAD_OPEN, HEAD_SHOUT = L(0), L(2)
HEAD_CLOSED = p1.crop((0, 0, p1.width, CUT))
TORSO = p1.crop((0, CUT, p1.width, p1.height))


def keep_largest(img):
    from scipy import ndimage
    a = np.asarray(img).copy()
    lab, n = ndimage.label(a[..., 3] > 20, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        k = int(np.argmax(sizes)) + 1
        a[..., 3] = np.where(ndimage.binary_dilation(lab == k, iterations=2), a[..., 3], 0)
    return Image.fromarray(a, "RGBA")

TORSO = keep_largest(TORSO)
ARM_BACK, ARM_FRONT = L(3), L(4)
LEG_FRONT, LEG_BACK = L(5), L(6)
SPEAR = L(8)


def register(base, other, rows=200, rng=14):
    """투구 윗부분 알파가 가장 잘 겹치는 이동량 (other를 base에 맞춤)."""
    a = np.asarray(base)[..., 3][:rows] > 128
    b = np.asarray(other)[..., 3] > 128
    best, bo = -1, (0, 0)
    for dy in range(-rng, rng + 1):
        for dx in range(-rng, rng + 1):
            ys0, xs0 = max(0, dy), max(0, dx)
            sub = b[ys0 - dy: ys0 - dy + rows, :]
            h = min(a.shape[0] - ys0, sub.shape[0])
            w = min(a.shape[1] - xs0, sub.shape[1])
            if h <= 0 or w <= 0:
                continue
            s = (a[ys0:ys0 + h, xs0:xs0 + w] & sub[:h, :w]).sum()
            if s > best:
                best, bo = s, (dx, dy)
    return bo


def head_variant(kind):
    """기본 머리 위에 다른 표정 머리를 정렬해 얹음 (목 가리개는 기본 머리 것 유지)."""
    img = HEAD_OPEN.copy()
    if kind == "open":
        return img
    other = HEAD_CLOSED if kind == "closed" else HEAD_SHOUT
    dx, dy = register(HEAD_OPEN, other)
    if kind == "shout":   # 외침 머리는 통째로 쓰되 위치만 맞춤
        out = Image.new("RGBA", img.size)
        out.alpha_composite(other.crop((0, 0, min(other.width, img.width - max(dx, 0)), min(other.height, img.height - max(dy, 0)))), (max(dx, 0), max(dy, 0)))
        return out
    img.alpha_composite(other, (dx, dy))
    return img

HEADS = {k: head_variant(k) for k in ("open", "closed", "shout")}

# 관절·기준점 (각 파츠 로컬 원본 픽셀)
J = {
    "head_neck": (168, 312),          # 머리: 목 가리개 아래 가운데
    "torso_neck": (153, 25),          # 몸통: 목 자리
    "torso_sh_back": (78, 40),        # 몸통: 뒤 어깨(화면 왼쪽)
    "torso_sh_front": (222, 40),      # 몸통: 앞 어깨(화면 오른쪽)
    "torso_hip_back": (110, 250), "torso_hip_front": (196, 250),
    "arm_back_sh": (52, 40), "arm_back_fist": (129, 128),
    "arm_front_sh": (58, 38), "arm_front_fist": (141, 119),
    "leg_back_hip": (44, 14), "leg_front_hip": (46, 20),
    "spear_grip": (520, 33),          # 창: 앞손이 쥐는 자리
}
GROUND_PAD = 6


# ------------------------------------------------------------------ 변환·합성

def place(canvas, img, pivot, pos, ang=0.0, sx=1.0, sy=1.0):
    """img의 pivot을 canvas의 pos에 놓고, pivot 기준으로 ang(도, 시계 방향) 회전·확대."""
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    px, py = pos
    data = (c/sx, s/sx, pivot[0] - (c*px + s*py)/sx,
            -s/sy, c/sy, pivot[1] - (-s*px + c*py)/sy)
    t = img.convert("RGBa").transform(canvas.size, Image.AFFINE, data, resample=Image.BICUBIC).convert("RGBA")
    canvas.alpha_composite(t)


def rot(v, ang):
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return (v[0]*c - v[1]*s, v[0]*s + v[1]*c)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


CW, CH = 1500, 1100
TORSO_AT = (560, 420)   # 몸통 왼쪽 위 (캔버스)


def build(pose):
    """pose: lean, squash(sx,sy), head(kind), head_rot, front_ang, spear_ang, slide, legs(back, front 각도)"""
    T = lambda p: add(TORSO_AT, p)
    up = Image.new("RGBA", (CW, CH))
    lower = Image.new("RGBA", (CW, CH))
    # 다리 (몸통 엉덩이 아래)
    lb, lf = pose.get("legs", (0, 0))
    place(lower, LEG_BACK, J["leg_back_hip"], T(J["torso_hip_back"]), lb)
    place(lower, LEG_FRONT, J["leg_front_hip"], T(J["torso_hip_front"]), lf)
    # 몸통
    place(up, TORSO, (0, 0), TORSO_AT)
    # 앞팔과 창
    SF, SB = T(J["torso_sh_front"]), T(J["torso_sh_back"])
    af = pose.get("front_ang", 0)
    F = add(SF, rot(sub(J["arm_front_fist"], J["arm_front_sh"]), af))
    sa = pose.get("spear_ang", -12)
    u = rot((1, 0), sa)
    # 뒷팔: 주먹이 창 줄 위에 오도록 어깨 각도를 풂
    vb = sub(J["arm_back_fist"], J["arm_back_sh"])
    best = None
    for k in range(-900, 901):
        ab = k / 10
        B = add(SB, rot(vb, ab))
        d = sub(B, F)
        cross = d[0]*u[1] - d[1]*u[0]
        along = d[0]*u[0] + d[1]*u[1]
        if along < -40 and (best is None or abs(cross) < best[0] - 1e-9 or (abs(abs(cross) - best[0]) < .5 and abs(ab) < abs(best[1]))):
            best = (abs(cross), ab)
    ab = best[1]
    slide = pose.get("slide", 0)
    grip = add(F, (u[0]*slide, u[1]*slide))
    place(up, SPEAR, J["spear_grip"], grip, sa)
    place(up, ARM_BACK, J["arm_back_sh"], SB, ab)
    place(up, ARM_FRONT, J["arm_front_sh"], SF, af)
    # 머리
    hk = pose.get("head", "open")
    place(up, HEADS[hk], J["head_neck"], T(J["torso_neck"]), pose.get("head_rot", 0))
    # 상체 전체 기울기·눌림 (엉덩이 중앙 기준)
    hip = T(((J["torso_hip_back"][0] + J["torso_hip_front"][0]) / 2, 250))
    sx, sy = pose.get("squash", (1, 1))
    full = Image.new("RGBA", (CW, CH))
    full.alpha_composite(lower)
    lean_up = Image.new("RGBA", (CW, CH))
    place(lean_up, up, hip, add(hip, pose.get("shift", (0, 0))), pose.get("lean", 0), sx, sy)
    full.alpha_composite(lean_up)
    tip = add(grip, rot((SPEAR.width - J["spear_grip"][0] - 4, 0), sa))
    tip = add(hip, rot((tip[0] - hip[0], tip[1] - hip[1]), pose.get("lean", 0)))
    return full, {"tip": add(tip, pose.get("shift", (0, 0)))}


# ------------------------------------------------------------------ 동작
IDLE = [dict(squash=(1, 1), spear_ang=-12),
        dict(squash=(1.012, .988), spear_ang=-11.5, head_rot=1),
        dict(squash=(1.022, .978), spear_ang=-11, head_rot=2, head="closed"),
        dict(squash=(1.01, .99), spear_ang=-11.5, head_rot=1)]
ATTACK = [dict(spear_ang=-12),
          dict(lean=-5, squash=(1.03, .96), front_ang=14, spear_ang=-6, slide=-70, head_rot=-3),
          dict(lean=-8, squash=(1.05, .94), front_ang=22, spear_ang=-2, slide=-120, head_rot=-4, legs=(4, -4)),
          dict(lean=8, squash=(.96, 1.04), front_ang=-14, spear_ang=-4, slide=95, head="shout", head_rot=4, shift=(46, 0), legs=(-6, 8)),
          dict(lean=10, squash=(.97, 1.03), front_ang=-16, spear_ang=-5, slide=115, head="shout", head_rot=5, shift=(54, 0), legs=(-6, 8)),
          dict(lean=2, front_ang=-2, spear_ang=-10, slide=30, head_rot=1, shift=(8, 0))]


def render_all():
    frames = {"idle": [build(p) for p in IDLE], "attack": [build(p) for p in ATTACK]}
    return frames


# ------------------------------------------------------------------ 내보내기
SCALE = 2
BOARD_H = 84                       # 투구 상모 끝 ~ 발바닥 = 보드 84px
NAME = "unit-spear-jangsu"
PAD_COL = (154, 59, 46)


def pad_layer(size, ax, gy, k):
    from PIL import ImageDraw
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    rx, ry = 22*SCALE*1.05, 5*SCALE
    d.ellipse((ax - rx, gy - ry - 2*SCALE, ax + rx, gy + ry - 2*SCALE), fill=PAD_COL + (140,), outline=PAD_COL + (255,), width=3)
    return im


def shadow_layer(size, ax, gy):
    from PIL import ImageDraw, ImageFilter
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    rx, ry = 18*SCALE, 4*SCALE
    d.ellipse((ax - rx, gy - ry - 1*SCALE, ax + rx, gy + ry - 1*SCALE), fill=(30, 36, 20, 80))
    return im.filter(ImageFilter.GaussianBlur(2))


def export(frames_all):
    base0 = frames_all["idle"][0][0]
    bb = base0.getbbox()
    gy = bb[3]
    ax = TORSO_AT[0] + (J["torso_hip_back"][0] + J["torso_hip_front"][0]) / 2
    k = BOARD_H * SCALE / (bb[3] - bb[1])
    meta_all = {}
    sheets = {}
    for anim, fps in (("idle", 6), ("attack", 12)):
        fr = frames_all[anim]
        boxes = [im.getbbox() for im, _ in fr]
        left = max(ax - min(b[0] for b in boxes), 0) + 12
        right = max(max(b[2] for b in boxes) - ax, 0) + 12
        top = gy - min(b[1] for b in boxes) + 8
        # 보드 정수 크기로 맞춤
        Wb = math.ceil((left + right) * k / SCALE)
        Hb = math.ceil((top + 4/k*SCALE*2) * k / SCALE)
        Wp, Hp = Wb*SCALE, Hb*SCALE
        axp = round(left * k)                       # 프레임 안 발밑 x (@2x)
        gyp = Hp - 2*SCALE                          # 프레임 안 발바닥 y (@2x)
        for pad in (True, False):
            name = NAME + ("" if pad else "-nopad")
            imgs, frames = [], {}
            for i, (im, ev) in enumerate(fr):
                small = im.resize((round(im.width*k), round(im.height*k)), Image.LANCZOS)
                cell = Image.new("RGBA", (Wp, Hp))
                cell.alpha_composite(pad_layer((Wp, Hp), axp, gyp, k) if pad else shadow_layer((Wp, Hp), axp, gyp))
                ox, oy = round(axp - ax*k), round(gyp - gy*k)
                cell.alpha_composite(small, (ox, oy)) if ox >= 0 and oy >= 0 else cell.alpha_composite(small.crop((max(-ox, 0), max(-oy, 0), small.width, small.height)), (max(ox, 0), max(oy, 0)))
                imgs.append(cell)
                key = f"{name}-{anim}-{i}"
                frames[key] = {"frame": {"x": i*Wp, "y": 0, "w": Wp, "h": Hp}, "duration": round(1000/fps),
                               "anchor": {"x": round(axp/Wp, 4), "y": round(gyp/Hp, 4)}}
                if anim == "attack" and i == 3:
                    tx, ty = ev["tip"]
                    frames[key]["events"] = {"hit": {"x": round(ox + tx*k, 1), "y": round(oy + ty*k, 1)}}
            sheet = Image.new("RGBA", (Wp*len(imgs), Hp))
            for i, c in enumerate(imgs):
                sheet.paste(c, (i*Wp, 0))
            sheet.save(os.path.join(OUT, f"{name}-{anim}.png"))
            json.dump({"frames": frames, "animations": {anim: list(frames)},
                       "meta": {"image": f"{name}-{anim}.png", "size": {"w": sheet.width, "h": Hp}, "scale": str(SCALE), "fps": fps,
                                "board_frame": {"w": Wb, "h": Hb},
                                "source": "Gemini parts sheet → cutout rig (tools/rig_spear.py)",
                                "note": "anchor = 발밑(하단 중앙에 가까운 점, 비율). 창이 몸 밖으로 나와 프레임이 72보다 넓음. events.hit = 창끝 타격점(@2x 프레임 픽셀). 좌우 반전 시 x' = w - x."}},
                      open(os.path.join(OUT, f"{name}-{anim}.json"), "w"), ensure_ascii=False, indent=1)
            if pad:
                sheets[anim] = (imgs, frames, axp, gyp)
            if anim == "idle":
                imgs[0].save(os.path.join(OUT, f"{name}.png"))
    return sheets


if __name__ == "__main__":
    fr = render_all()
    # 확인용: 원본 크기 1/2로 한 줄
    row = Image.new("RGBA", (CW//2*6, CH//2*2), (185, 197, 158, 255))
    for r, k in enumerate(("idle", "attack")):
        for i, (im, _) in enumerate(fr[k]):
            row.alpha_composite(im.resize((CW//2, CH//2), Image.LANCZOS), (i*CW//2, r*CH//2))
    row.save(os.path.join(OUT, "_check.png"))
    sh = export(fr)
    for a, (imgs, frames, axp, gyp) in sh.items():
        print(a, imgs[0].size, axp, gyp, [v.get("events") for v in frames.values() if "events" in v])
