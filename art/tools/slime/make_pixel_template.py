"""제미나이에게 도트 크기를 알려 줄 견본: 장비 없는 기본 슬라임 몸 4개 (폭 14·16·18·20도트).

출력: art/source/pixel/slime-body-template.png (창병) + slime-body-template-<병과>.png  (1도트 = 12px)
      배경은 하늘색, 수군(파랑 몸)만 마젠타
제미나이는 '픽셀 아트'라고만 하면 잔 도트·그라데이션으로 그리므로, 이 그림을 첨부해 도트 크기를 그대로 따르게 한다.
실행: python3 art/tools/slime/make_pixel_template.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT_DIR = os.path.join(ROOT, 'art/source/pixel')
S = 12
# 병과: (파일 이름, 몸 색, 배경)
BRANCHES = {
    'spear':   ('slime-body-template.png', (240, 106, 85), (0, 255, 255)),
    'archer':  ('slime-body-template-archer.png', (116, 201, 94), (0, 255, 255)),
    'gunner':  ('slime-body-template-gunner.png', (164, 134, 224), (0, 255, 255)),
    'cavalry': ('slime-body-template-cavalry.png', (240, 177, 69), (0, 255, 255)),
    'navy':    ('slime-body-template-navy.png', (85, 166, 234), (255, 0, 255)),
    'mystic':  ('slime-body-template-mystic.png', (180, 187, 197), (0, 255, 255)),
}
BG = (0, 255, 255)
OUTLINE = (42, 33, 28)
HI, BASE, SHADE = (255, 143, 117), (240, 106, 85), (201, 74, 58)


def tones(base):
    b = np.array(base, float)
    hi = tuple(int(v) for v in np.clip(b + (255 - b) * 0.35, 0, 255))
    sh = tuple(int(v) for v in np.clip(b * 0.8, 0, 255))
    return hi, tuple(base), sh
WHITE, EYE, CHEEK = (255, 246, 224), (42, 33, 28), (255, 160, 165)


def slime(w):
    h = round(w * 0.78)
    g = np.zeros((h, w), np.uint8)       # 0 빈칸, 1 몸
    cx = (w - 1) / 2
    for y in range(h):
        t = y / (h - 1)
        if t < 0.62:                      # 둥근 윗부분 (반타원)
            yy = 1 - (t + 0.5 / h) / 0.62
            half = (w / 2) * max(0.0, 1 - abs(yy) ** 2.2) ** 0.5
        else:                             # 아래 몸통
            half = w / 2
        for x in range(w):
            if abs(x - cx) <= half - 0.15: g[y, x] = 1
    img = np.zeros((h + 2, w + 2, 3), np.uint8); img[:] = BG
    body = np.zeros((h + 2, w + 2), bool); body[1:-1, 1:-1] = g > 0
    for y in range(h + 2):
        for x in range(w + 2):
            if body[y, x]:
                fy = (y - 1) / h; fx = (x - 1) / w
                c = BASE
                if ((fx - 0.38) / 0.36) ** 2 + ((fy - 0.22) / 0.2) ** 2 < 1: c = HI
                if fy > 0.84 or ((fx - 0.5) / 0.5) ** 2 + ((fy - 0.45) / 0.62) ** 2 > 0.78 and fx > 0.6: c = SHADE
                img[y, x] = c
    # 외곽선
    pad = np.pad(body, 1)
    near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    img[(~body) & near] = OUTLINE
    out = np.zeros((h + 4, w + 4, 3), np.uint8); out[:] = BG
    out[1:-1, 1:-1] = img
    b = np.zeros((h + 4, w + 4), bool); b[2:-2, 2:-2] = g > 0
    ob = np.pad(b, 1); nb = ob[:-2, 1:-1] | ob[2:, 1:-1] | ob[1:-1, :-2] | ob[1:-1, 2:]
    out[(~b) & nb] = OUTLINE
    # 반짝임·얼굴 (몸 좌표 + 2)
    oy, ox = 2, 2
    sx, sy = round(w * 0.22), round(h * 0.18)
    out[oy + sy, ox + sx] = WHITE; out[oy + sy, ox + sx + 1] = WHITE; out[oy + sy + 1, ox + sx] = WHITE
    ey = round(h * 0.45); el = round(cx - w * 0.17); er = round(cx + w * 0.17)
    for ex in (el, er):
        out[oy + ey, ox + ex] = EYE; out[oy + ey + 1, ox + ex] = EYE
    cy = ey + 2
    out[oy + cy, ox + el - 2] = CHEEK; out[oy + cy, ox + el - 1] = CHEEK
    out[oy + cy, ox + er + 1] = CHEEK; out[oy + cy, ox + er + 2] = CHEEK
    my = ey + 2; mx = round(cx)
    out[oy + my, ox + mx] = EYE
    if w % 2 == 0: out[oy + my, ox + mx - 1] = EYE
    # 작은 손 (오른쪽)
    hy = round(h * 0.62)
    out[oy + hy, ox + w - 1] = SHADE; out[oy + hy, ox + w] = SHADE
    out[oy + hy - 1, ox + w] = OUTLINE; out[oy + hy + 1, ox + w] = OUTLINE; out[oy + hy, ox + w + 1] = OUTLINE
    return out


def main():
    global HI, BASE, SHADE, BG
    for name, (fname, base, bg) in BRANCHES.items():
        if name == 'spear':
            HI, BASE, SHADE = (255, 143, 117), (240, 106, 85), (201, 74, 58)
        else:
            HI, BASE, SHADE = tones(base)
        BG = bg
        render(os.path.join(OUT_DIR, fname))


def render(OUT):
    sprites = [slime(w) for w in (14, 16, 18, 20)]
    gap = 6
    H = max(s.shape[0] for s in sprites) + 8
    W = sum(s.shape[1] for s in sprites) + gap * 5
    canvas = np.zeros((H, W, 3), np.uint8); canvas[:] = BG
    x = gap
    for s in sprites:
        canvas[H - 4 - s.shape[0]:H - 4, x:x + s.shape[1]] = s
        x += s.shape[1] + gap
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(canvas).resize((W * S, H * S), Image.NEAREST).save(OUT)
    print(OUT, W, H)


if __name__ == '__main__':
    main()
