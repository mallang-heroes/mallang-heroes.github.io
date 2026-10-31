"""도트로 그린 제미나이 슬라임 줄(4등급)을 도트 격자에 맞춰 정리 → 등급별 도트 원본 + 맵 미리보기.

입력: art/source/gemini/slime-pixel/<병과>-ranks-pixel.png (하늘색 또는 마젠타 배경, 도트 크기·격자는 자동으로 찾음)
출력: art/source/gemini/slime-pixel/dots/<병과>-<등급>.png   1도트 = 1px 원본 (투명)
      art/preview/slime-pixel/<병과>-pixel-on-map.png, -pixel-ranks.png
게임 크기: 1도트 = @2x 4px (보드 2). 확대는 NEAREST만 쓴다(부드럽게 줄이지 않음).
실행: python3 art/tools/slime/snap_pixel_slime.py spear archer ...  (여러 병과면 섞어 올린 mixed 미리보기도 만든다)
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
RANKS = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu']
BODY = {   # 병과별 몸 기본색 (견본과 같음) — 발 위치를 찾을 때 씀
    'spear': (240, 106, 85), 'archer': (116, 201, 94), 'gunner': (164, 134, 224),
    'cavalry': (240, 177, 69), 'navy': (85, 166, 234), 'mystic': (180, 187, 197),
}


DOT2X = 4                      # 게임 @2x에서 1도트 픽셀 수 (보드 2 — 장수 받침 30도트 = 보드 60, 칸 63 안)
FOOT_DY = 14


def find_grid(a):
    """도트 크기·시작점 찾기: 가로·세로 같은 도트 크기에서 칸 가운데와 가장자리 색이 가장 같아지는 값."""
    h, w = a.shape[:2]
    X = a[h // 10:h - h // 10].astype(float)
    Y = a[:, w // 50:w - w // 50].astype(float)

    def score(img, p, horizontal):
        best = None
        n = img.shape[1] if horizontal else img.shape[0]
        for o in np.arange(0, p, 0.5):
            xs = np.arange(o, n - p, p)
            pick = (lambda f: img[:, (xs + p * f).astype(int)]) if horizontal else (lambda f: img[(xs + p * f).astype(int)])
            c = pick(0.5)
            v = np.abs(c - pick(0.12)).mean() + np.abs(c - pick(0.88)).mean()
            if best is None or v < best[0]: best = (v, o)
        return best

    # 견본 방식(1도트 = 12px 견본 → 1024 폭 결과)이면 도트가 약 9px. 잔 값(절반 크기)에 걸리지 않게 8~11만 본다.
    best = None
    for p in np.arange(8, 11.01, 0.05):
        sx = score(X, p, True)
        if best is None or sx[0] < best[0]: best = (sx[0], round(float(p), 2), sx[1])
    p = best[1]
    return p, best[2], score(Y, p, False)[1]


def offsets(a, P):
    """도트 크기 P가 정해졌을 때 격자 시작점만 찾기."""
    h, w = a.shape[:2]
    best = []
    for horizontal, img in ((True, a[h // 10:h - h // 10].astype(float)), (False, a[:, w // 50:w - w // 50].astype(float))):
        n = img.shape[1] if horizontal else img.shape[0]
        b = None
        for o in np.arange(0, P, 0.5):
            xs = np.arange(o, n - P, P)
            pick = (lambda f: img[:, (xs + P * f).astype(int)]) if horizontal else (lambda f: img[(xs + P * f).astype(int)])
            c = pick(0.5)
            v = np.abs(c - pick(0.12)).mean() + np.abs(c - pick(0.88)).mean()
            if b is None or v < b[0]: b = (v, o)
        best.append(b[1])
    return best


def snap(path, P=None):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    H, W = a.shape[:2]
    if P is None:
        P, OX, OY = find_grid(a)
    else:
        OX, OY = offsets(a, P)
    print('grid', P, OX, OY)
    xs = np.arange(OX - P, W, P); ys = np.arange(OY, H, P)
    out = np.zeros((len(ys), len(xs), 4), np.uint8)
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            y0, y1 = int(max(0, y + 1)), int(min(H, y + P - 1)); x0, x1 = int(max(0, x + 1)), int(min(W, x + P - 1))
            if y1 <= y0 or x1 <= x0: continue
            c = np.median(a[y0:y1, x0:x1].reshape(-1, 3), 0)
            out[j, i, :3] = c
            is_bg = (c[1] > 200 and c[2] > 200 and c[0] < 120) or (c[0] > 200 and c[2] > 200 and c[1] < 80)
            out[j, i, 3] = 0 if is_bg else 255
    # 배경과 맞닿은 하늘색 섞인 도트(가장자리 번짐) 두 겹까지 벗기기
    c = out[..., :3].astype(int)
    tint = (c[..., 1] - c[..., 0] > 60) & (c[..., 2] - c[..., 0] > 60) & (c[..., 1] > 130)
    for _ in range(2):
        m = out[..., 3] > 0
        edge = m & ~ndimage.binary_erosion(m)
        out[edge & tint, 3] = 0
    # 안쪽에 남은 밝은 하늘색 번짐(창 자루 옆 등)도 버림
    strong = (c[..., 1] - c[..., 0] > 45) & (c[..., 2] - c[..., 0] > 45) & (np.abs(c[..., 1] - c[..., 2]) < 35)   # 청록·하늘색 계열
    out[strong, 3] = 0
    global FACE_BLOBS
    FACE_BLOBS = face_blobs(a, P, OX - P, OY)
    return out


FACE_BLOBS = []


def face_blobs(a, P, gx, gy):
    """원본에서 몸 색에 둘러싸인 작은 진한 덩어리(눈·입) → 도트 좌표 (가운데 y, 가운데 x, 넓이)."""
    dark = a.sum(2) < 200
    lab, n = ndimage.label(dark)
    H, W = dark.shape
    found = []
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None: continue
        h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
        if h > P * 3.2 or w > P * 4.5 or h * w < P * P * 0.3: continue
        blob = lab[sl] == k
        y0, y1 = max(0, sl[0].start - 3), min(H, sl[0].stop + 3); x0, x1 = max(0, sl[1].start - 3), min(W, sl[1].stop + 3)
        ring = np.ones((y1 - y0, x1 - x0), bool)
        ring[sl[0].start - y0:sl[0].stop - y0, sl[1].start - x0:sl[1].stop - x0] &= ~blob
        rc = a[y0:y1, x0:x1][ring & ~dark[y0:y1, x0:x1]]
        if len(rc) < ring.sum() * 0.85: continue
        if ((rc[:, 1] > 200) & (rc[:, 2] > 200) & (rc[:, 0] < 120)).mean() > 0.05: continue
        ys, xs = np.where(blob)
        found.append(((ys.mean() + sl[0].start - gy) / P, (xs.mean() + sl[1].start - gx) / P, len(ys) / (P * P), h / P, w / P))
    return found


def split(d, body_rgb):
    m = d[..., 3] > 0
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    m = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 4])
    cols = m.any(0)
    xs = np.where(cols)[0]
    gaps, x = [], xs[0]
    while x < xs[-1]:
        if not cols[x]:
            s0 = x
            while not cols[x]: x += 1
            gaps.append((x - s0, s0, x))
        x += 1
    cuts = sorted(sorted(gaps, reverse=True)[:3], key=lambda g: g[1])
    b = [xs[0]] + [c for g in cuts for c in (g[1], g[2])] + [xs[-1] + 1]
    parts = []
    for i in range(0, len(b), 2):
        x0, x1 = b[i], b[i + 1]
        mm = m[:, x0:x1]
        ys = np.where(mm.any(1))[0]
        piece = d[ys[0]:ys[-1] + 1, x0:x1].copy()
        piece[..., 3] = np.where(mm[ys[0]:ys[-1] + 1], 255, 0)
        # 발: 몸(빨강) 가장 아래 줄, 그 줄 몸 가운데
        c = piece[..., :3].astype(int)
        base = np.array(body_rgb)
        body = (piece[..., 3] > 0) & ((np.abs(c - base).sum(2) < 110) | (np.abs(c - base * 0.8).sum(2) < 80))
        rows = np.where(body.sum(1) >= 3)[0]
        fy = rows[-1] + 1
        widest = max(rows, key=lambda r: body[r].sum())
        wc = np.where(body[widest])[0]
        parts.append((piece, ((wc[0] + wc[-1] + 1) / 2, fy), wc[-1] - wc[0] + 1, (ys[0], x0)))
    return parts


RECRUIT_BODY = 14   # 견본의 군졸 몸 폭(도트). 제미나이가 크게 그렸으면 도트 크기를 다시 잡는다.
TEMPLATE_W = [14, 16, 18, 20]
OUTLINE = (42, 33, 28)
CHEEK = (255, 160, 165)


def redraw_face(piece, off, body_rgb):
    """얼굴 다시 찍기: 제미나이 도트는 격자가 고르지 않아 1도트짜리 눈·입이 줄이면서 뭉개진다.
    원본에서 찾은 눈 두 개의 자리를 기준으로, 얼굴 줄의 진한·분홍 점을 몸색으로 지우고
    견본과 같은 얼굴(눈 1×2, 볼 2도트씩, 입)을 다시 찍는다."""
    oy, ox = off
    H, W = piece.shape[:2]
    blobs = [(y - oy, x - ox, a, h, w) for y, x, a, h, w in FACE_BLOBS if 0 <= y - oy < H and 0 <= x - ox < W]
    # 눈: 키가 폭보다 크고 크기가 비슷하며 같은 높이인 두 덩어리
    best = None
    for i in range(len(blobs)):
        for j in range(i + 1, len(blobs)):
            b1, b2 = blobs[i], blobs[j]
            if abs(b1[0] - b2[0]) > 0.8 or abs(b1[1] - b2[1]) < 3: continue
            if b1[3] < b1[4] * 1.1 or b2[3] < b2[4] * 1.1: continue
            score = abs(b1[2] - b2[2]) + abs(b1[0] - b2[0])
            if best is None or score < best[0]: best = (score, b1, b2)
    if best is None:
        print('  눈을 못 찾음 — 얼굴은 그대로')
        return
    l, r = sorted([best[1], best[2]], key=lambda b: b[1])
    ey = int(round((l[0] + r[0]) / 2 - 1.0))
    el, er = int(l[1]), int(r[1])
    c = piece[..., :3].astype(int)
    base = np.array(body_rgb)
    for y in range(ey - 2, ey + 4):
        for x in range(el - 5, er + 6):
            if not (0 <= y < H and 0 <= x < W) or piece[y, x, 3] == 0: continue
            v = c[y, x]
            pink = v[0] > 200 and v[1] < 190 and v[2] > 140 and v[0] - v[1] > 40
            facey = abs(v - base).sum() > 90 and abs(v - base * 0.8).sum() > 90 and v.sum() < 330   # 몸색과 다른 어두운 점(입 옆 잡티)
            if v.sum() < 260 or pink or (facey and ey <= y <= ey + 2 and el - 1 <= x <= er + 1):
                # 외곽선(바로 옆이 투명)은 건드리지 않음
                if any(not (0 <= yy < H and 0 <= xx < W) or piece[yy, xx, 3] == 0 for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))):
                    continue
                nb = [c[yy, xx] for yy, xx in ((y - 1, x), (y, x - 1), (y - 2, x), (y, x + 1), (y + 1, x))
                      if 0 <= yy < H and 0 <= xx < W and np.abs(c[yy, xx] - base).sum() < 150]
                piece[y, x, :3] = nb[0] if nb else base
                c[y, x] = piece[y, x, :3]

    def put(y, x, col):
        if 0 <= y < H and 0 <= x < W and piece[y, x, 3] > 0:
            piece[y, x, :3] = col
    for ex in (el, er):
        put(ey, ex, OUTLINE); put(ey + 1, ex, OUTLINE)
    for x in (el - 2, el - 1, er + 1, er + 2): put(ey + 2, x, CHEEK)
    mid = (el + er) / 2
    if (er - el) % 2 == 0: put(ey + 2, int(mid), OUTLINE)
    else: put(ey + 2, int(mid), OUTLINE); put(ey + 2, int(mid) + 1, OUTLINE)


def build(branch):
    src = os.path.join(ROOT, f'art/source/gemini/slime-pixel/{branch}-ranks-pixel.png')
    d = snap(src)
    parts = split(d, BODY[branch])
    bw = parts[0][2]
    if abs(bw - RECRUIT_BODY) > 1:
        a = np.asarray(Image.open(src).convert('RGB'))
        P0 = find_grid(a)[0]
        print(f'{branch}: 군졸 몸 {bw}도트 → 도트 크기 {P0} × {bw}/{RECRUIT_BODY}로 다시')
        d = snap(src, round(P0 * bw / RECRUIT_BODY, 2))
        parts = split(d, BODY[branch])
    dots_dir = os.path.join(ROOT, 'art/source/gemini/slime-pixel/dots'); os.makedirs(dots_dir, exist_ok=True)
    sprites = []
    for (piece, foot, bw, off), rk in zip(parts, RANKS):
        redraw_face(piece, off, BODY[branch])
        Image.fromarray(piece).save(os.path.join(dots_dir, f'{branch}-{rk}.png'))
        h, w = piece.shape[:2]
        big = Image.fromarray(piece).resize((w * DOT2X, h * DOT2X), Image.NEAREST)
        sprites.append((big, (foot[0] * DOT2X, foot[1] * DOT2X)))
        print(branch, rk, f'{w}x{h} dots, body {bw} dots, foot {foot}')
    return sprites


def map_preview(all_sprites, name):
    prev = os.path.join(ROOT, 'art/preview/slime-pixel'); os.makedirs(prev, exist_ok=True)
    data = json.load(open(os.path.join(ROOT, 'assets/data/map-portrait.json'), encoding='utf-8'))
    tiles = sorted(data['tiles'], key=lambda t: (t[1], t[0]))
    bg = Image.open(os.path.join(ROOT, 'art/preview/map-portrait/bg.png')).convert('RGBA')
    ov = Image.new('RGBA', bg.size); dr = ImageDraw.Draw(ov)
    for cx, cy in tiles:
        dr.rounded_rectangle([cx * 2 - 63, cy * 2 - 63, cx * 2 + 63, cy * 2 + 63], radius=30,
                             fill=(255, 255, 255, 46), outline=(42, 33, 28, 70), width=3)
    bg.alpha_composite(ov)
    plan = {0: 0, 1: 1, 2: 2, 3: 3, 4: 3, 5: 0, 6: 0, 8: 1, 10: 1, 11: 2, 13: 0,
            16: 2, 18: 1, 19: 0, 20: 3, 22: 3, 24: 2}
    branches = list(all_sprites)
    for _, i, r in sorted((tiles[i][1], i, r) for i, r in plan.items()):
        sprites = all_sprites[branches[i % len(branches)]]
        sp, (fx, fy) = sprites[r]
        cx, cy = tiles[i]
        bg.alpha_composite(sp, (round(cx * 2 - fx), round((cy + FOOT_DY) * 2 - fy)))
    bg.convert('RGB').save(os.path.join(prev, f'{name}-pixel-on-map.png'))


def ranks_preview(sprites, branch):
    prev = os.path.join(ROOT, 'art/preview/slime-pixel')
    row = Image.new('RGBA', (4 * 150, 280), (122, 160, 72, 255))
    ov = Image.new('RGBA', row.size); dr = ImageDraw.Draw(ov)
    for j in range(4):
        dr.rounded_rectangle([j * 150 + 12, 144, j * 150 + 138, 270], radius=30, fill=(255, 255, 255, 46), outline=(42, 33, 28, 90), width=3)
    row.alpha_composite(ov)
    for j, (sp, (fx, fy)) in enumerate(sprites):
        row.alpha_composite(sp, (round(j * 150 + 75 - fx), round(207 + FOOT_DY * 2 - fy)))
    row.resize((row.width * 2, row.height * 2), Image.NEAREST).convert('RGB').save(os.path.join(prev, f'{branch}-pixel-ranks.png'))


def main(*branches):
    branches = branches or ('spear',)
    all_sprites = {b: build(b) for b in branches}
    for b, sp in all_sprites.items():
        ranks_preview(sp, b)
        map_preview({b: sp}, b)
    if len(branches) > 1:
        map_preview(all_sprites, 'mixed')


if __name__ == '__main__':
    main(*sys.argv[1:])
