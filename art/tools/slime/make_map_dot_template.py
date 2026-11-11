"""맵과 같은 도트 크기(1도트 = 보드 3)의 기본 슬라임 견본 (2026-11-11).

맵 도트가 보드 3이라 유닛도 같은 굵기로 다시 그린다.
  몸 폭  군졸 10 · 정병 12 · 군관 14 · 장수 16 도트 (= 보드 30·36·42·48, 지금 게임 크기 그대로)
  눈: 작은 둘(10·12)은 1×2도트, 큰 둘(14·16)은 2×2도트 + 흰 반짝임 1도트. 볼 1도트, 입 1~2도트.
  색은 맵에 맞춘 기본 슬라임 그대로 — 몸 (220,108,86), 외곽선 청회색 (60,68,70).
시트: 칸 4개 가로, 칸 = 24×30도트(창이 머리 위로 나올 자리), 발 = 칸 아래에서 3도트 위 가운데.
1도트 = 16px로 키워 1536×480 그림, 배경 하늘색.
출력: art/source/pixel/map-dot-template-base.png (+ 맵 위 미리보기 art/preview/slime-base/map-dot-template-on-map.png)
실행: python3 art/tools/slime/make_map_dot_template.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
PX = 16
CELL_W, CELL_H, FOOT_UP = 24, 30, 3
WIDTHS = [10, 12, 14, 16]
BODY = (220, 108, 86)
HI = (238, 146, 118)
SH = (178, 80, 70)
OUTLINE = (60, 68, 70)
WHITE = (255, 248, 236)
CHEEK = (245, 150, 150)
BG = (0, 255, 255)


def body_mask(w):
    h = round(w * 0.72)
    m = np.zeros((h, w), bool)
    for y in range(h):
        t = (y + 0.5) / h
        half = w / 2 if t >= 0.62 else (w / 2) * (1 - (1 - t / 0.62) ** 2.2) ** 0.5
        for x in range(w):
            m[y, x] = abs(x + 0.5 - w / 2) <= half + 0.15
    return m


def slime(w):
    m = body_mask(w)
    h = m.shape[0]
    img = np.zeros((h + 2, w + 2, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            if not m[y, x]: continue
            fx, fy = (x + 0.5) / w, (y + 0.5) / h
            c = BODY
            if ((fx - 0.34) / 0.26) ** 2 + ((fy - 0.22) / 0.2) ** 2 < 1: c = HI
            if y == h - 1 or (fx > 0.8 and fy > 0.45): c = SH
            img[y + 1, x + 1] = (*c, 255)
    a = img[..., 3] > 0
    p = np.pad(a, 1)
    ring = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]) & ~a
    img[ring] = (*OUTLINE, 255)
    # 얼굴 (몸 좌표 +1)
    big = w >= 14
    ew = 2 if big else 1
    ey = 1 + round(h * 0.40)
    gap = round(w * 0.2)
    cx = 1 + w // 2
    lx, rx = cx - gap - ew, cx + gap
    for ex in (lx, rx):
        img[ey:ey + 2, ex:ex + ew] = (*OUTLINE, 255)
        if big: img[ey, ex + ew - 1] = (*WHITE, 255)
    cy = ey + 2
    img[cy, lx - 1] = (*CHEEK, 255)
    img[cy, rx + ew] = (*CHEEK, 255)
    mw = 2 if w % 2 == 0 else 1
    img[cy, cx - mw // 2 - (0 if mw == 1 else 0):cx - mw // 2 + mw] = (*OUTLINE, 255)
    # 반짝임 1도트
    img[1 + max(1, round(h * 0.18)), 1 + round(w * 0.25)] = (*WHITE, 255)
    return img


def sheet():
    s = np.zeros((CELL_H, CELL_W * 4, 4), np.uint8)
    s[..., :3] = BG; s[..., 3] = 255
    feet = []
    for i, w in enumerate(WIDTHS):
        sp = slime(w)
        h2, w2 = sp.shape[:2]
        x0 = i * CELL_W + (CELL_W - w2) // 2
        y0 = CELL_H - FOOT_UP - h2 + 1
        a = sp[..., 3] > 0
        s[y0:y0 + h2, x0:x0 + w2][a] = sp[a]
        feet.append((sp, x0 - i * CELL_W, y0))
    return s, [f[0] for f in feet]


def preview(sprites):
    """맵 위에 실제 크기로 (맵 @2x = 1도트 6px)."""
    bg = Image.open(os.path.join(ROOT, 'art/preview/map-portrait/bg.png')).convert('RGBA')
    k = 6
    spots = [(154.5, 393), (223.5, 393), (292.5, 393), (361.5, 393),
             (154.5, 726), (223.5, 726), (292.5, 726), (361.5, 726)]
    for j, (x, y) in enumerate(spots):
        sp = sprites[j % 4]
        im = Image.fromarray(sp).resize((sp.shape[1] * k, sp.shape[0] * k), Image.NEAREST)
        fx, fy = x * 2, (y + 14) * 2
        px = int(round((fx - im.width / 2) / k) * k)
        py = int(round((fy - im.height + k) / k) * k)
        bg.alpha_composite(im, (px, py))
    return bg.crop((60 * 2, 300 * 2, 520 * 2, 780 * 2))


def main():
    s, sprites = sheet()
    os.makedirs(os.path.join(ROOT, 'art/source/pixel'), exist_ok=True)
    Image.fromarray(s[..., :3]).resize((s.shape[1] * PX, s.shape[0] * PX), Image.NEAREST).save(
        os.path.join(ROOT, 'art/source/pixel/map-dot-template-base.png'))
    preview(sprites).convert('RGB').save(os.path.join(ROOT, 'art/preview/slime-base/map-dot-template-on-map.png'))
    print('ok')


if __name__ == '__main__':
    main()
