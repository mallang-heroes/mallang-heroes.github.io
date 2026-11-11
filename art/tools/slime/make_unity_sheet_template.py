"""유니티 시트용 큰 슬라임 견본 (2026-11-11, 유니티 전환 후).

얼굴이 뭉개지던 문제(몸 폭 14~20도트, 눈 1도트)를 풀려고 몸을 키운다:
  몸 폭  군졸 20 · 정병 22 · 군관 25 · 장수 28 도트, 눈 2×3도트(흰 반짝임 1도트), 볼 3도트, 입 3도트.
시트 모양: 칸 4개를 가로로, 칸 하나 = 40×48도트, 발(몸 바닥 가운데) = 칸 아래에서 4도트 위 가운데.
1도트 = 8px로 그려서 1280×384 그림. 배경 하늘색(수군만 마젠타).
출력: art/source/pixel/unity-sheet-template-<병과>.png
실행: python3 art/tools/slime/make_unity_sheet_template.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'art/source/pixel')
PX = 8
CELL_W, CELL_H, FOOT_UP = 40, 48, 4
WIDTHS = [20, 22, 25, 28]
OUTLINE = (42, 33, 28)
WHITE = (255, 250, 240)
CHEEK = (255, 150, 160)
BRANCHES = {
    'spear': ((240, 106, 85), (0, 255, 255)),
    'archer': ((116, 201, 94), (0, 255, 255)),
    'gunner': ((164, 134, 224), (0, 255, 255)),
    'cavalry': ((240, 177, 69), (0, 255, 255)),
    'navy': ((85, 166, 234), (255, 0, 255)),
    'mystic': ((180, 187, 197), (0, 255, 255)),
}


def tones(base):
    b = np.array(base, float)
    hi = tuple(int(v) for v in np.clip(b + (255 - b) * 0.38, 0, 255))
    sh = tuple(int(v) for v in np.clip(b * 0.78, 0, 255))
    return hi, tuple(base), sh


def body_mask(w):
    h = round(w * 0.74)
    m = np.zeros((h, w), bool)
    for y in range(h):
        t = (y + 0.5) / h
        if t < 0.6:
            yy = 1 - t / 0.6
            half = (w / 2) * max(0.0, 1 - abs(yy) ** 2.4) ** 0.5
        else:
            half = w / 2
        for x in range(w):
            if abs(x + 0.5 - w / 2) <= half: m[y, x] = True
    return m


def slime(w, base):
    hi, mid, sh = tones(base)
    m = body_mask(w)
    h = m.shape[0]
    img = np.zeros((h + 2, w + 5, 4), np.uint8)   # 오른쪽에 손 자리 3칸
    for y in range(h):
        for x in range(w):
            if not m[y, x]: continue
            fx, fy = (x + 0.5) / w, (y + 0.5) / h
            c = mid
            if ((fx - 0.36) / 0.3) ** 2 + ((fy - 0.24) / 0.2) ** 2 < 1: c = hi
            if fy > 0.86 or (fx > 0.84 and fy > 0.35): c = sh
            img[y + 1, x + 1] = (*c, 255)
    # 외곽선
    a = img[..., 3] > 0
    p = np.pad(a, 1)
    ring = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]) & ~a
    img[ring] = (*OUTLINE, 255)
    # 얼굴 (몸 좌표 + 1)
    ox, oy = 1, 1
    ey = round(h * 0.42)
    gap = round(w * 0.2)
    cx = w // 2
    for ex in (cx - gap - 1, cx + gap - 1):
        img[oy + ey:oy + ey + 3, ox + ex:ox + ex + 2] = (*OUTLINE, 255)
        img[oy + ey, ox + ex] = (*WHITE, 255)
    cy = ey + 3
    for x0 in (cx - gap - 4, cx + gap + 1):
        img[oy + cy, ox + x0:ox + x0 + 3] = (*CHEEK, 255)
    img[oy + cy, ox + cx - 2:ox + cx + 1] = (*OUTLINE, 255)
    # 반짝임
    img[oy + round(h * 0.16), ox + round(w * 0.24):ox + round(w * 0.24) + 2] = (*WHITE, 255)
    img[oy + round(h * 0.16) + 1, ox + round(w * 0.24)] = (*WHITE, 255)
    # 오른쪽 작은 손
    hy = round(h * 0.62)
    img[oy + hy:oy + hy + 2, ox + w:ox + w + 2] = (*sh, 255)
    img[oy + hy - 1, ox + w:ox + w + 2] = (*OUTLINE, 255)
    img[oy + hy + 2, ox + w:ox + w + 2] = (*OUTLINE, 255)
    img[oy + hy:oy + hy + 2, ox + w + 2] = (*OUTLINE, 255)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (base, bg) in BRANCHES.items():
        sheet = np.zeros((CELL_H, CELL_W * 4, 4), np.uint8)
        sheet[..., :3] = bg; sheet[..., 3] = 255
        for i, w in enumerate(WIDTHS):
            s = slime(w, base)
            h2, w2 = s.shape[:2]
            x0 = i * CELL_W + (CELL_W - w2) // 2
            y0 = CELL_H - FOOT_UP - h2 + 1      # 몸 바닥(외곽선 위 줄)이 발 줄
            region = sheet[y0:y0 + h2, x0:x0 + w2]
            a = s[..., 3] > 0
            region[a] = s[a]
        Image.fromarray(sheet[..., :3]).resize((CELL_W * 4 * PX, CELL_H * PX), Image.NEAREST).save(
            os.path.join(OUT, f'unity-sheet-template-{name}.png'))
    print('ok')


if __name__ == '__main__':
    main()
