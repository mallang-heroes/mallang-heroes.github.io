"""도트로 그린 제미나이 슬라임 줄(4등급)을 도트 격자에 맞춰 정리 → 등급별 도트 원본 + 맵 미리보기.

입력: art/source/gemini/slime-pixel/<병과>-ranks-pixel.png (하늘색 배경, 1도트 ≈ 9px)
출력: art/source/gemini/slime-pixel/dots/<병과>-<등급>.png   1도트 = 1px 원본 (투명)
      art/preview/slime-pixel/<병과>-pixel-on-map.png, -pixel-ranks.png
게임 크기: 1도트 = @2x 6px (보드 3, 궁 도트 크기와 비슷). 확대는 NEAREST만 쓴다(부드럽게 줄이지 않음).
실행: python3 art/tools/slime/snap_pixel_slime.py spear
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
RANKS = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu']
P, OX, OY = 9.0, 8.0, 0.0      # 도트 크기, 격자 시작점 (찾은 값)
DOT2X = 6                      # 게임 @2x에서 1도트 픽셀 수 (보드 3 = 궁 도트와 비슷)
FOOT_DY = 14


def snap(path):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    H, W = a.shape[:2]
    xs = np.arange(OX - P, W, P); ys = np.arange(OY, H, P)
    out = np.zeros((len(ys), len(xs), 4), np.uint8)
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            y0, y1 = int(max(0, y + 2)), int(min(H, y + P - 2)); x0, x1 = int(max(0, x + 2)), int(min(W, x + P - 2))
            if y1 <= y0 or x1 <= x0: continue
            c = np.median(a[y0:y1, x0:x1].reshape(-1, 3), 0)
            out[j, i, :3] = c
            out[j, i, 3] = 0 if (c[1] > 200 and c[2] > 200 and c[0] < 120) else 255
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
    return out


def split(d):
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
        body = (piece[..., 3] > 0) & (c[..., 0] > 170) & (c[..., 1] < 140) & (c[..., 2] < 130)
        rows = np.where(body.sum(1) >= 3)[0]
        fy = rows[-1] + 1
        fx_cols = np.where(body[rows[-1]])[0]
        widest = max(rows, key=lambda r: body[r].sum())
        wc = np.where(body[widest])[0]
        parts.append((piece, ((wc[0] + wc[-1] + 1) / 2, fy), wc[-1] - wc[0] + 1))
    return parts


def main(branch='spear'):
    d = snap(os.path.join(ROOT, f'art/source/gemini/slime-pixel/{branch}-ranks-pixel.png'))
    parts = split(d)
    dots_dir = os.path.join(ROOT, 'art/source/gemini/slime-pixel/dots'); os.makedirs(dots_dir, exist_ok=True)
    prev = os.path.join(ROOT, 'art/preview/slime-pixel'); os.makedirs(prev, exist_ok=True)
    sprites = []
    for (piece, foot, bw), rk in zip(parts, RANKS):
        Image.fromarray(piece).save(os.path.join(dots_dir, f'{branch}-{rk}.png'))
        h, w = piece.shape[:2]
        big = Image.fromarray(piece).resize((w * DOT2X, h * DOT2X), Image.NEAREST)
        sprites.append((big, (foot[0] * DOT2X, foot[1] * DOT2X)))
        print(rk, f'{w}x{h} dots, body {bw} dots, foot {foot}')

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
    for _, i, r in sorted((tiles[i][1], i, r) for i, r in plan.items()):
        sp, (fx, fy) = sprites[r]
        cx, cy = tiles[i]
        bg.alpha_composite(sp, (round(cx * 2 - fx), round((cy + FOOT_DY) * 2 - fy)))
    bg.convert('RGB').save(os.path.join(prev, f'{branch}-pixel-on-map.png'))

    row = Image.new('RGBA', (4 * 150, 280), (122, 160, 72, 255))
    ov = Image.new('RGBA', row.size); dr = ImageDraw.Draw(ov)
    for j in range(4):
        dr.rounded_rectangle([j * 150 + 12, 144, j * 150 + 138, 270], radius=30, fill=(255, 255, 255, 46), outline=(42, 33, 28, 90), width=3)
    row.alpha_composite(ov)
    for j, (sp, (fx, fy)) in enumerate(sprites):
        row.alpha_composite(sp, (round(j * 150 + 75 - fx), round(207 + FOOT_DY * 2 - fy)))
    row.resize((row.width * 2, row.height * 2), Image.NEAREST).convert('RGB').save(os.path.join(prev, f'{branch}-pixel-ranks.png'))


if __name__ == '__main__':
    main(*(sys.argv[1:] or ['spear']))
