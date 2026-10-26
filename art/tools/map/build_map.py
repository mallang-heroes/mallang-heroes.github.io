#!/usr/bin/env python3
"""제미나이 맵 소스 4장 → 게임용 맵 레이어 (보드 1560x720).

1) 배경: 가이드 여백 잘라 보드 크기로, 워터마크·그림 속 동굴 지우기, 길 중심선 추출 → 경로 JSON
2) 장식: 배경 제거 → 이름 붙이기 → 보드 크기로 → 배치 규칙대로 놓기
3) 건물: 배경 제거 → 분리·보정 → 공통 배율로 → 자리 배치, 들썩임 3프레임
4) 동굴: 초록 배경 제거 → 보라 기운 회전·맥동 4프레임
"""
import json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from keying import key_out, components

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
OUT = os.path.join(HERE, "out")
for d in ("png", "preview"):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)
BW, BH, MAP_W = 1560, 720, 1404
SC = 2                      # @2x
GUIDE_Y0, GUIDE_Y1 = 59, 709  # 가이드에서 보드가 차지한 세로 범위


def save2x(img, name):
    img.save(os.path.join(OUT, "png", name))

# ================================================================== 1. 배경

def inpaint_from(arr, mask, dx, dy, feather=6):
    """mask 영역을 (dx,dy)만큼 떨어진 곳의 픽셀로 채움 (경계는 부드럽게, 주변 색에 맞춤)."""
    src = np.roll(np.roll(arr, -dy, axis=0), -dx, axis=1)
    ring = ndimage.binary_dilation(mask, iterations=feather*3) & ~ndimage.binary_dilation(mask, iterations=feather)
    if ring.any():
        src = src + (arr[ring].mean(0) - src[ring].mean(0))
        # 위아래 밝기 기울기도 맞춤 (화면 위쪽이 더 밝음)
        ys = np.where(ring)[0]
        if np.ptp(ys) > 20:
            for c in range(3):
                a1 = np.polyfit(ys, arr[ring][:, c], 1)
                b1 = np.polyfit(ys, src[ring][:, c], 1)
                yy = np.arange(arr.shape[0])[:, None]
                src[..., c] += (a1[0] - b1[0]) * (yy - ys.mean())
    m = ndimage.gaussian_filter(mask.astype(np.float32), feather)
    m = np.clip(m * 2.2, 0, 1)[..., None]
    m = np.maximum(m, mask[..., None].astype(np.float32))
    return (arr * (1 - m) + src * m).astype(arr.dtype)


def build_bg():
    im = np.asarray(Image.open(os.path.join(SRC, "map-bg.png")).convert("RGB")).astype(np.float32)
    H, W, _ = im.shape
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    # 워터마크 반짝이 (오른쪽 아래): 주변보다 밝고 채도 낮은 픽셀
    wm = np.zeros((H, W), bool)
    y0, y1, x0, x1 = int(H*.79), int(H*.93), int(W*.87), int(W*.955)
    lum = (r + g + b) / 3
    sat = np.max(im, 2) - np.min(im, 2)
    wm[y0:y1, x0:x1] = (lum[y0:y1, x0:x1] > ndimage.median_filter(lum, 41)[y0:y1, x0:x1] + 12) & (sat[y0:y1, x0:x1] < 90)
    wm = ndimage.binary_dilation(wm, iterations=4)
    im = inpaint_from(im, wm, -90, 0, 3)
    # 그림 속 동굴 지우기 (새 동굴 스프라이트를 얹기 위해): 동굴·그림자 영역을 풀로 덮되 흙길은 남김
    yy, xx = np.mgrid[0:H, 0:W]
    cave = ((xx >= 1025) & (xx <= 1300) & (yy < 138)) | ((xx >= 1100) & (xx <= 1300) & (yy < 158))
    spur_keep = (xx >= 1104) & (xx <= 1164) & (yy >= 146)
    cave &= ~spur_keep
    im = inpaint_from(im, cave, -640, 380, 10)
    # 가이드 여백 잘라 보드 크기로
    crop = Image.fromarray(np.clip(im, 0, 255).astype(np.uint8)).crop((0, GUIDE_Y0, W, GUIDE_Y1))
    board = crop.resize((BW, BH), Image.LANCZOS)
    return board


def road_mask(board):
    a = np.asarray(board).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (r > g + 4) & (r - b > 45) & (r > 140)
    m = ndimage.binary_opening(m, iterations=2)
    m = ndimage.binary_closing(m, iterations=3)
    return m


def extract_path(mask):
    """중심(702,360)에서 사방으로 광선을 쏴 흙길 띠의 가운데를 이어 순환로 중심선을 만든다."""
    cx, cy = 702.0, 370.0
    pts = []
    H, W = mask.shape
    for k in range(1440):
        a = 2 * math.pi * k / 1440
        dx, dy = math.cos(a), math.sin(a)
        t, inside, t0 = 0.0, False, None
        while True:
            x, y = cx + dx*t, cy + dy*t
            if not (0 <= x < W and 0 <= y < H):
                break
            v = mask[int(y), int(x)]
            if v and not inside:
                inside, t0 = True, t
            elif not v and inside:
                if t - t0 > 18:          # 길 폭보다 얇은 것(자갈 등)은 무시
                    break
                inside = False
            t += 0.5
        if t0 is not None:
            tm = (t0 + t) / 2
            pts.append((cx + dx*tm, cy + dy*tm, t - t0))
    P = np.array([(p[0], p[1]) for p in pts])
    widths = np.array([p[2] for p in pts])
    # 갈림길과 합쳐져 띠가 넓어진 곳은 이웃 점으로 보간 (중심선이 갈림길 쪽으로 꺾이지 않게)
    med = np.median(widths)
    bad = ndimage.binary_dilation(widths > med * 1.25, iterations=6)
    if bad.any() and not bad.all():
        idx = np.arange(len(P))
        good = ~bad
        for c in (0, 1):
            P[bad, c] = np.interp(idx[bad], idx[good], P[good, c], period=len(P))
    # 다듬기 (원형 이동 평균) 후 등간격 재샘플
    k = 9
    Ps = np.array([np.mean(np.take(P, range(i - k, i + k + 1), axis=0, mode="wrap"), axis=0) for i in range(len(P))])
    seg = np.r_[0, np.cumsum(np.hypot(*np.diff(np.vstack([Ps, Ps[:1]]), axis=0).T))]
    total = seg[-1]
    s = np.arange(0, total, 2.0)
    loop = np.vstack([np.interp(s, seg, np.r_[Ps[:, i], Ps[0, i]]) for i in (0, 1)]).T
    return loop, float(total), float(np.median(widths))


def extract_spur(mask, loop):
    """동굴에서 순환로까지 곧게 내려오는 갈림길: 오른쪽 위 열들의 흙길 가운데."""
    xs = []
    for y in range(102, 118):
        row = np.where(mask[y, 1220:1360])[0]
        if len(row) > 20:
            xs.append(1220 + (row.min() + row.max()) / 2)
    x = float(np.median(xs))
    # 순환로와 만나는 점: x 열에서 순환로 중심선과 가장 가까운 점
    j = int(np.argmin(np.abs(loop[:, 0] - x) + 3*np.abs(loop[:, 1] - 205) * (loop[:, 1] < 300)))
    j = int(np.argmin([abs(p[0] - x) + (0 if p[1] < 300 else 1e6) for p in loop]))
    return x, j

# ================================================================== 2. 장식
PROP_NAMES = ["tree-round", "tree-zelkova", "tree-tall", "pine-a", "pine-b",
              "rock-a", "rock-b", "bush", "flowers-white", "flowers-pink", "flowers-yellow", "tuft-a", "tuft-b"]
PROP_H = {"tree-round": 72, "tree-zelkova": 66, "tree-tall": 78, "pine-a": 66, "pine-b": 74,
          "rock-a": 18, "rock-b": 20, "bush": 22, "flowers-white": 18, "flowers-pink": 18, "flowers-yellow": 18,
          "tuft-a": 15, "tuft-b": 15}
BLOCKING = {"tree-round", "tree-zelkova", "tree-tall", "pine-a", "pine-b", "rock-a", "rock-b", "bush"}


def ground_shadow(w, h, rx, ry, alpha=70):
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    d.ellipse((w/2 - rx, h - ry*2.2, w/2 + rx, h - ry*.2), fill=(30, 40, 20, alpha))
    return im.filter(ImageFilter.GaussianBlur(max(1, ry*.5)))


def build_props():
    img = key_out(os.path.join(SRC, "map-props.png"))
    cs = components(img, 6)
    cs.sort(key=lambda c: (c[0][1] // 150, c[0][0]))
    props = {}
    for name, (bb, im, _) in zip(PROP_NAMES, cs):
        hb = PROP_H[name]
        k = hb * SC / im.height
        small = im.resize((max(1, round(im.width*k)), round(im.height*k)), Image.LANCZOS)
        if name in BLOCKING:   # 바닥 그림자 (위 줄 그림에는 없어서 추가)
            pad = 6*SC
            canvas = Image.new("RGBA", (small.width + pad*2, small.height + pad))
            rx = small.width * (.42 if name.startswith(("tree", "pine")) else .5)
            canvas.alpha_composite(ground_shadow(canvas.width, canvas.height, rx, rx*.22), (0, 0))
            canvas.alpha_composite(small, (pad, 0))
            small = canvas
        props[name] = small
        save2x(small, f"map-prop-{name}.png")
    return props

# ================================================================== 3. 건물
BLD_KEYS = ["palace", "spear", "archer", "gunner", "cavalry", "navy", "mystic"]
SLOT_FOOT = {"palace": (702, 432), "spear": (330, 372), "archer": (436, 372), "gunner": (542, 372),
             "cavalry": (862, 372), "navy": (968, 372), "mystic": (1074, 372)}   # 건물 바닥 가운데 (보드)


def fix_archer(arr, ox, oy):
    """궁병 막사 앞 대포 지우기: 벽 안쪽은 벽 무늬로 채우고, 벽 밖은 투명하게."""
    H, W, _ = arr.shape
    yy, xx = np.mgrid[0:H, 0:W]
    X, Y = xx + ox, yy + oy                     # 시트 좌표
    box = (X >= 1198) & (X <= 1300) & (Y >= 272) & (Y <= 352)
    wall = Y < 322 - 0.628 * (X - 1175)
    in_wall = box & wall
    dx, dy = -62, int(round(62 * 0.628))
    src = np.roll(np.roll(arr, -dy, axis=0), -dx, axis=1)
    out = arr.copy()
    out[in_wall] = src[in_wall]
    out[box & ~wall, 3] = 0
    return out


def fix_mystic_watermark(arr, ox, oy):
    H, W, _ = arr.shape
    rgb = arr[..., :3].astype(np.float32)
    lum = rgb.mean(2)
    yy, xx = np.mgrid[0:H, 0:W]
    X, Y = xx + ox, yy + oy
    box = (X >= 1222) & (X <= 1290) & (Y >= 618) & (Y <= 685)
    med = np.stack([ndimage.median_filter(rgb[..., c], 15) for c in range(3)], 2)
    bright = box & (lum > med.mean(2) + 10) & (arr[..., 3] > 200)
    bright = ndimage.binary_dilation(bright, iterations=2) & box
    out = arr.copy()
    out[bright, :3] = med[bright].astype(np.uint8)
    # 마젠타 위에 걸친 반짝이(분홍빛 흰색)는 지움
    src = np.asarray(Image.open(os.path.join(SRC, "map-buildings.png")).convert("RGB")).astype(np.int32)
    sub = src[oy:oy + H, ox:ox + W]
    pink = (sub[..., 0] > 232) & (sub[..., 2] > 232) & (sub[..., 1] > 80) & box
    out[ndimage.binary_dilation(pink, iterations=2) & box & (out[..., 3] < 250), 3] = 0
    out[pink, 3] = 0
    return out


def build_buildings():
    img = key_out(os.path.join(SRC, "map-buildings.png"))
    cs = components(img, 10)
    cs.sort(key=lambda c: (c[0][1] // 150, c[0][0]))
    groups = []
    for bb, im, _ in cs:
        if bb[2] - bb[0] > 600 and bb[1] > 300:      # 기병+수군이 붙어 있음 → 둘로
            a = np.asarray(im).copy()
            cut = 712 - bb[0]
            left, right = a.copy(), a.copy()
            left[:, cut:, 3] = 0
            right[:, :cut, 3] = 0
            for part, x0 in ((left, bb[0]), (right, bb[0])):
                pi = Image.fromarray(part, "RGBA")
                pb = pi.getbbox()
                groups.append(((x0 + pb[0], bb[1] + pb[1], x0 + pb[2], bb[1] + pb[3]), pi.crop(pb)))
        else:
            groups.append((bb, im))
    groups.sort(key=lambda g: (g[0][1] // 150, g[0][0]))
    blds = {}
    for key, (bb, im) in zip(BLD_KEYS, groups):
        a = np.asarray(im).copy()
        if key == "archer":
            a = fix_archer(a, bb[0], bb[1])
        if key == "mystic":
            a = fix_mystic_watermark(a, bb[0], bb[1])
        blds[key] = Image.fromarray(a, "RGBA").crop(Image.fromarray(a, "RGBA").getbbox())
    # 공통 배율: 막사 몸체가 비슷한 크기가 되도록 막사 폭 중앙값 → 보드 94px
    med = sorted(blds[k].width for k in BLD_KEYS[1:])[3]
    kb = 94 / med
    out = {}
    for key, im in blds.items():
        k = kb * (1.05 if key == "palace" else 1.0) * SC
        small = im.resize((round(im.width*k), round(im.height*k)), Image.LANCZOS)
        out[key] = small
    return out


def bounce_frames(im):
    """유닛이 들어갈 때 들썩임 3프레임 (바닥 기준 눌림 → 늘어남 → 원래)."""
    frames = []
    for sx, sy in ((1.04, .94), (.98, 1.04), (1.0, 1.0)):
        w, h = round(im.width*sx), round(im.height*sy)
        c = Image.new("RGBA", (round(im.width*1.06), round(im.height*1.06)))
        c.alpha_composite(im.resize((w, h), Image.LANCZOS), ((c.width - w)//2, c.height - h))
        frames.append(c)
    return frames

# ================================================================== 4. 동굴

def build_cave(target_w=150):
    img = key_out(os.path.join(SRC, "map-cave.png"), "green")
    cs = components(img, 6, 2000)
    cs.sort(key=lambda c: -c[2])
    bb, cave, _ = cs[0]
    a = np.asarray(cave).astype(np.float32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    purple = (b > g + 35) & (r > g + 5) & (al > 200)
    purple = ndimage.binary_opening(purple, iterations=2)
    lab, n = ndimage.label(purple)
    if n:
        sizes = ndimage.sum(purple, lab, range(1, n + 1))
        purple = lab == (int(np.argmax(sizes)) + 1)
    hole = ndimage.binary_fill_holes(ndimage.binary_closing(purple, iterations=6))
    ys, xs = np.where(hole)
    cx, cy = xs.mean(), ys.mean()
    glow = a.copy()
    glow[..., 3] = np.where(hole, al, 0)
    base = a.copy()
    base[hole, :3] = base[hole, :3] * .35 + np.array([40, 10, 60]) * .65
    base_im = Image.fromarray(base.astype(np.uint8), "RGBA")
    glow_im = Image.fromarray(glow.astype(np.uint8), "RGBA")
    hole_im = Image.fromarray((hole*255).astype(np.uint8), "L")
    frames = []
    for i in range(4):
        rot = glow_im.rotate(-i*22, resample=Image.BICUBIC, center=(cx, cy))
        k = 1 + .18*math.sin(i/4*2*math.pi)
        arr = np.asarray(rot).astype(np.float32)
        arr[..., :3] = np.clip(arr[..., :3]*k, 0, 255)
        rot = Image.fromarray(arr.astype(np.uint8), "RGBA")
        f = base_im.copy()
        clipped = Image.new("RGBA", f.size)
        clipped.paste(rot, (0, 0), hole_im)
        f.alpha_composite(clipped)
        frames.append(f)
    # 입구 바닥 가운데 (갈림길이 시작되는 점)
    foot = (cx, ys.max())
    k = target_w * SC / cave.width
    small = [f.resize((round(f.width*k), round(f.height*k)), Image.LANCZOS) for f in frames]
    return small, (foot[0]*k, foot[1]*k)

# ================================================================== 배치·합성

def place_props(props, loop, blds_rects, spur_x, cave_rect):
    rnd = random.Random(20261026)
    L = loop[::3]

    def d_road(x, y):
        d = np.hypot(L[:, 0] - x, L[:, 1] - y).min()
        if abs(x - spur_x) < 60 and y < 230:
            d = min(d, abs(x - spur_x))
        return d

    def blocked(x, y, w, margin):
        if d_road(x, y) < 26 + margin:
            return True
        for (x0, y0, x1, y1) in blds_rects + [cave_rect]:
            if x0 - margin - w/2 < x < x1 + margin + w/2 and y0 - margin < y < y1 + margin + 30:
                return True
        return False
    trees = []
    kinds = ["tree-round", "tree-zelkova", "tree-tall", "pine-a", "pine-b"]
    spots = [(34, 82), (26, 300), (32, 520), (60, 712), (420, 68), (860, 62), (1100, 66),
             (380, 714), (760, 714), (1130, 714), (1388, 650), (1400, 330), (1480, 120), (1505, 430), (1470, 700)]
    for x, y in spots:
        x += rnd.uniform(-6, 6); y += rnd.uniform(-3, 3)
        if not blocked(x, y - 10, 40, 8):
            trees.append((rnd.choice(kinds), x, y))
    for x, y in [(225, 372), (1185, 372)]:
        if not blocked(x, y - 10, 40, 8):
            trees.append((rnd.choice(["pine-a", "pine-b", "tree-tall"]), x, y))
    small_kinds = ["rock-a", "rock-b", "bush", "flowers-white", "flowers-pink", "flowers-yellow", "tuft-a", "tuft-b"]
    weights = [2, 2, 2, 2, 2, 2, 3, 3]
    smalls, tries, n_in, n_out = [], 0, 0, 0
    inside = lambda x, y: 80 < x < 1330 and 150 < y < 570
    while (n_in < 24 or n_out < 10) and tries < 9000:
        tries += 1
        x, y = rnd.uniform(10, BW - 10), rnd.uniform(16, BH - 4)
        ins = inside(x, y)
        if (ins and n_in >= 24) or (not ins and n_out >= 10):
            continue
        if blocked(x, y - 6, 20, 45):
            continue
        if any(math.hypot(x - tx, y - ty + 12) < 70 for _, tx, ty in trees):
            continue
        if any(math.hypot(x - px, y - py) < 60 for _, px, py in smalls):
            continue
        smalls.append((rnd.choices(small_kinds, weights)[0], x, y))
        n_in += ins; n_out += not ins
    return trees, smalls


def compose(bg, loop, spur, props, blds, cave_frames, cave_foot, cave_pos, trees, smalls, with_guides=False):
    big = bg.resize((BW*SC, BH*SC), Image.LANCZOS).convert("RGBA")
    items = []
    for k, x, y in trees + smalls:
        im = props[k]
        items.append((y, im, (round(x*SC - im.width/2), round(y*SC - im.height))))
    for k, im in blds.items():
        fx, fy = SLOT_FOOT[k]
        items.append((fy, im, (round(fx*SC - im.width/2), round(fy*SC - im.height))))
    items.sort(key=lambda t: t[0])
    cv = cave_frames[0]
    big.alpha_composite(cv, (round(cave_pos[0]*SC - cave_foot[0]), round(cave_pos[1]*SC - cave_foot[1])))
    for _, im, pos in items:
        big.alpha_composite(im, pos)
    if with_guides:
        d = ImageDraw.Draw(big)
        pts = [(p[0]*SC, p[1]*SC) for p in loop[::4]]
        d.line(pts + pts[:1], fill=(255, 40, 40, 255), width=3)
        d.line([(spur[0][0]*SC, spur[0][1]*SC), (spur[1][0]*SC, spur[1][1]*SC)], fill=(255, 40, 40, 255), width=3)
        d.line([(MAP_W*SC, 0), (MAP_W*SC, BH*SC)], fill=(255, 255, 255, 160), width=2)
    return big


def main():
    bg = build_bg()
    bg.save(os.path.join(OUT, "png", "map-bg-1x.png"))
    bg.resize((BW*SC, BH*SC), Image.LANCZOS).save(os.path.join(OUT, "png", "map-bg.png"))
    mask = road_mask(bg)
    loop, total, width = extract_path(mask)
    spur_x, j = extract_spur(mask, loop)
    loop = np.roll(loop, -j, axis=0)                     # 합류점에서 시작
    # 시계 방향 확인 (화면 좌표에서 면적 부호가 양수면 시계 방향)
    area = 0.5*np.sum(loop[:, 0]*np.roll(loop[:, 1], -1) - np.roll(loop[:, 0], -1)*loop[:, 1])
    if area < 0:
        loop = np.vstack([loop[:1], loop[1:][::-1]])
    props = build_props()
    blds = build_buildings()
    for k, im in blds.items():
        name = "map-bld-palace" if k == "palace" else f"map-bld-barracks-{k}"
        save2x(im, f"{name}.png")
        fr = bounce_frames(im)
        sheet = Image.new("RGBA", (fr[0].width*3, fr[0].height))
        frames = {}
        for i, f in enumerate(fr):
            sheet.paste(f, (i*f.width, 0))
            frames[f"{name}-enter-{i}"] = {"frame": {"x": i*f.width, "y": 0, "w": f.width, "h": f.height},
                                           "duration": 80, "anchor": {"x": .5, "y": 1.0}}
        sheet.save(os.path.join(OUT, "png", f"{name}-enter.png"))
        json.dump({"frames": frames, "animations": {"enter": list(frames)},
                   "meta": {"image": f"{name}-enter.png", "scale": str(SC), "fps": 12,
                            "board_size": {"w": round(im.width/SC), "h": round(im.height/SC)},
                            "foot_board": dict(zip("xy", SLOT_FOOT[k]))}},
                  open(os.path.join(OUT, "png", f"{name}-enter.json"), "w"), ensure_ascii=False, indent=1)
    cave_frames, cave_foot = build_cave()
    cave_bottom = 104
    cave_pos = (spur_x, cave_bottom)
    cw, ch = cave_frames[0].width, cave_frames[0].height
    sheet = Image.new("RGBA", (cw*4, ch))
    frames = {}
    for i, f in enumerate(cave_frames):
        sheet.paste(f, (i*cw, 0))
        frames[f"map-spawn-cave-{i}"] = {"frame": {"x": i*cw, "y": 0, "w": cw, "h": ch}, "duration": 166,
                                         "anchor": {"x": round(cave_foot[0]/cw, 4), "y": round(cave_foot[1]/ch, 4)}}
    sheet.save(os.path.join(OUT, "png", "map-spawn-cave.png"))
    json.dump({"frames": frames, "animations": {"glow": list(frames)},
               "meta": {"image": "map-spawn-cave.png", "scale": str(SC), "fps": 6,
                        "anchor_board": {"x": round(spur_x, 1), "y": cave_bottom}, "note": "anchor = 동굴 입구 바닥 가운데 = 갈림길 시작점"}},
              open(os.path.join(OUT, "png", "map-spawn-cave.json"), "w"), ensure_ascii=False, indent=1)
    # 건물·동굴 영역 (보드) → 장식 금지
    rects = []
    for k, im in blds.items():
        fx, fy = SLOT_FOOT[k]
        w, h = im.width/SC, im.height/SC
        rects.append((fx - w/2, fy - h, fx + w/2, fy))
    cave_rect = (spur_x - cw/SC/2, 0, spur_x + cw/SC/2, cave_bottom)
    trees, smalls = place_props(props, loop, rects, spur_x, cave_rect)
    junction = (float(loop[0][0]), float(loop[0][1]))
    spur = ((spur_x, cave_bottom - 4), (spur_x, junction[1]))
    full = compose(bg, loop, spur, props, blds, cave_frames, cave_foot, cave_pos, trees, smalls)
    full.save(os.path.join(OUT, "png", "map-full.png"))
    full.resize((BW, BH), Image.LANCZOS).save(os.path.join(OUT, "preview", "map-board.png"))
    full.resize((844, 390), Image.LANCZOS).save(os.path.join(OUT, "preview", "map-phone.png"))
    guide = compose(bg, loop, spur, props, blds, cave_frames, cave_foot, cave_pos, trees, smalls, True)
    guide.resize((BW, BH), Image.LANCZOS).save(os.path.join(OUT, "preview", "map-path-check.png"))
    # 경로 JSON
    sp = np.array([[spur_x, y] for y in np.arange(cave_bottom - 4, junction[1], 2.0)])
    json.dump({
        "board": {"w": BW, "h": BH}, "unit": "board px", "source": "Gemini map background (traced)",
        "roadWidth": round(width, 1),
        "spawn": {"cave_anchor": {"x": round(spur_x, 1), "y": cave_bottom},
                  "points": [[round(x, 1), round(y, 1)] for x, y in sp], "length": round(junction[1] - cave_bottom + 4, 1)},
        "loop": {"direction": "clockwise", "start": "spur junction", "length": round(total, 1),
                 "points": [[round(x, 1), round(y, 1)] for x, y in loop[::2]]},
        "buildings": {k: {"foot": dict(zip("xy", SLOT_FOOT[k])), "w": round(im.width/SC), "h": round(im.height/SC)} for k, im in blds.items()},
        "decorations": [{"kind": k, "x": round(x, 1), "y": round(y, 1), "blocks": k in BLOCKING} for k, x, y in trees + smalls],
        "rangeRadius": {"1": 95, "1.5": 113, "formula": "95 + (range-1)*36"},
    }, open(os.path.join(OUT, "png", "map-path.json"), "w"), ensure_ascii=False)
    print("loop", round(total), "width", round(width, 1), "spur_x", round(spur_x, 1), "junction", [round(v) for v in junction],
          "trees", len(trees), "smalls", len(smalls), {k: im.size for k, im in blds.items()})


if __name__ == "__main__":
    main()
