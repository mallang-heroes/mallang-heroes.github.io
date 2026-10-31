"""도트 기본 슬라임(제미나이 한 줄 4등급) → 등급별로 잘라 세로 맵 칸 위에 올려 보기.

입력: art/source/gemini/slime-pixel/<병과>-ranks.png (하늘색 #00FFFF 또는 마젠타 #FF00FF 배경, 왼쪽부터 군졸·정병·군관·장수)
      art/preview/map-portrait/bg.png, assets/data/map-portrait.json
출력: art/source/gemini/slime-pixel/cut/<병과>-<등급>.png  배경 지운 원본 크기 조각
      art/preview/slime-pixel/<병과>-on-map.png             맵 전체에 올린 그림
      art/preview/slime-pixel/<병과>-on-map-zoom.png        칸 부분 확대
      art/preview/slime-pixel/<병과>-ranks.png              네 등급을 칸 하나 크기에 나란히
실행: python3 art/tools/slime/preview_pixel_slime.py spear
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
RANKS = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu']
BOARD_PER_SRC = 0.35      # 제미나이 그림 1px → 보드 좌표 (장수 받침 폭 ≈ 칸 63 안쪽)
FOOT_DY = 14              # 유닛 발 = 칸 가운데 + 14 (MapData.footOf)


def load(branch):
    src = os.path.join(ROOT, f'art/source/gemini/slime-pixel/{branch}-ranks.png')
    a = np.asarray(Image.open(src).convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    cyan = (g > 225) & (b > 225) & (r < 110)
    magenta = (r > 225) & (b > 225) & (g < 60)
    bg = cyan if cyan[0, 0] else magenta
    fg = ~bg
    for _ in range(2):   # 배경색이 섞인 가장자리 한 겹씩 벗기기
        edge = fg & ~ndimage.binary_erosion(fg)
        tint = (b > r + 70) & (g > r + 70) if cyan[0, 0] else (r > g + 90) & (b > g + 90)
        fg &= ~(edge & tint)
    lab, n = ndimage.label(fg)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    fg = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 150])   # 작은 점(제미나이 표시 등) 버리기
    return a.astype(np.uint8), fg


def split(a, fg):
    """세로로 빈 칸을 경계 삼아 네 마리로 나눈다."""
    cols = fg.any(0)
    xs = np.where(cols)[0]
    gaps = []   # (폭, 시작, 끝) — 내용 사이 빈 열
    x = xs[0]
    while x < xs[-1]:
        if not cols[x]:
            s0 = x
            while not cols[x]: x += 1
            gaps.append((x - s0, s0, x))
        x += 1
    cuts = sorted(sorted(gaps, reverse=True)[:3], key=lambda g: g[1])   # 가장 넓은 틈 3개 = 네 마리 경계
    bounds = [xs[0]] + [c for g in cuts for c in (g[1], g[2])] + [xs[-1] + 1]
    merged = [(bounds[i], bounds[i + 1]) for i in range(0, len(bounds), 2)]
    out = []
    for x0, x1 in merged:
        m = fg[:, x0:x1]
        ys = np.where(m.any(1))[0]
        y0, y1 = ys[0], ys[-1] + 1
        rgba = np.dstack([a[y0:y1, x0:x1], (m[y0:y1] * 255).astype(np.uint8)])
        # 발 기준: 바닥 줄 근처 몸(빨강 계열) 가운데
        sub = a[y0:y1, x0:x1].astype(int)
        body = m[y0:y1] & (sub[..., 0] > 150) & (sub[..., 1] < 150)
        rows = np.where(body.any(1))[0]
        low = body[max(0, rows[-1] - 12):rows[-1] + 1]
        fx = np.where(low.any(0))[0]
        foot = ((fx[0] + fx[-1] + 1) / 2, rows[-1] + 1)
        out.append((Image.fromarray(rgba), foot))
    return out


def scaled(im, foot, k):
    w, h = im.size
    big = im.resize((round(w * k), round(h * k)), Image.LANCZOS)
    return big, (foot[0] * k, foot[1] * k)


def draw_tile(d, cx, cy, s=2):
    t = 63 * s / 2
    d.rounded_rectangle([cx * s - t, cy * s - t, cx * s + t, cy * s + t], radius=15 * s,
                        fill=(255, 255, 255, 46), outline=(42, 33, 28, 70), width=3)


def main(branch='spear'):
    a, fg = load(branch)
    parts = split(a, fg)
    cut_dir = os.path.join(ROOT, 'art/source/gemini/slime-pixel/cut')
    prev = os.path.join(ROOT, 'art/preview/slime-pixel')
    os.makedirs(cut_dir, exist_ok=True); os.makedirs(prev, exist_ok=True)
    for (im, foot), rk in zip(parts, RANKS):
        im.save(os.path.join(cut_dir, f'{branch}-{rk}.png'))
        print(rk, im.size, 'foot', foot)

    k = BOARD_PER_SRC * 2   # @2x 픽셀
    sprites = [scaled(im, f, k) for im, f in parts]
    data = json.load(open(os.path.join(ROOT, 'assets/data/map-portrait.json'), encoding='utf-8'))
    tiles = sorted(data['tiles'], key=lambda t: (t[1], t[0]))   # 위(3층)부터
    bg = Image.open(os.path.join(ROOT, 'art/preview/map-portrait/bg.png')).convert('RGBA')
    over = Image.new('RGBA', bg.size); d = ImageDraw.Draw(over)
    for cx, cy in tiles: draw_tile(d, cx, cy)
    bg.alpha_composite(over)
    # 배치: 3층 위 줄 = 군졸·정병·군관·장수·장수, 나머지는 섞어서
    plan = {0: 0, 1: 1, 2: 2, 3: 3, 4: 3,
            5: 0, 6: 0, 8: 1,
            10: 1, 11: 2, 13: 0,
            16: 2, 18: 1, 19: 0,
            20: 3, 22: 3, 24: 2}
    placed = sorted(((tiles[i][1], i, r) for i, r in plan.items()))
    for _, i, r in placed:
        sp, (fx, fy) = sprites[r]
        cx, cy = tiles[i]
        x = round(cx * 2 - fx); y = round((cy + FOOT_DY) * 2 - fy)
        bg.alpha_composite(sp, (x, y))
    bg.convert('RGB').save(os.path.join(prev, f'{branch}-on-map.png'))
    z = bg.crop((200, 560, 1000, 1080))
    z.resize((z.width * 2 // 1, z.height * 2 // 1), Image.NEAREST).convert('RGB').save(os.path.join(prev, f'{branch}-on-map-zoom.png'))

    # 등급 나란히 (칸 크기 기준)
    row = Image.new('RGBA', (4 * 150, 260), (122, 160, 72, 255))
    ov = Image.new('RGBA', row.size); d = ImageDraw.Draw(ov)
    for j in range(4):
        d.rounded_rectangle([j * 150 + 12, 124, j * 150 + 138, 250], radius=30, fill=(255, 255, 255, 46), outline=(42, 33, 28, 90), width=3)
    row.alpha_composite(ov)
    for j, (sp, (fx, fy)) in enumerate(sprites):
        row.alpha_composite(sp, (round(j * 150 + 75 - fx), round(187 + FOOT_DY * 2 - fy)))
    row.resize((row.width * 2, row.height * 2), Image.NEAREST).convert('RGB').save(os.path.join(prev, f'{branch}-ranks.png'))


if __name__ == '__main__':
    main(*(sys.argv[1:] or ['spear']))
