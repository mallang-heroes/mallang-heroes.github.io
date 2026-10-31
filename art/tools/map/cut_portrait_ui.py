"""도트 세로 화면 시안에서 UI 조각 잘라 내기 (맵 배경을 만들며 지운 것들).

입력: art/source/gemini/map-portrait/pixel-layout-empty-1170.png (폰 390pt @3x)
출력: art/source/gemini/map-portrait/cut/*.png  — 조각별 PNG (풀밭 위 조각은 풀을 투명하게)
      art/preview/map-portrait/cut-sheet.png    — 한눈에 보기
글자(3라운드, 졸2 정1 관0 등)가 그림에 박혀 있으므로 게임에 그대로 쓰기보다
UI 스킨·아이콘을 만들 때 기준 그림으로 쓴다.
실행: python3 art/tools/map/cut_portrait_ui.py (저장소 루트에서)
"""
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SRC = os.path.join(ROOT, 'art/source/gemini/map-portrait/pixel-layout-empty-1170.png')
OUT = os.path.join(ROOT, 'art/source/gemini/map-portrait/cut')
PREV = os.path.join(ROOT, 'art/preview/map-portrait/cut-sheet.png')
K = 1170 / 704   # 704 시안 좌표 → 1170 파일 좌표

# 이름: (x0, y0, x1, y1) — 704 시안 좌표, 풀 위에 있으면 grass=True
PIECES = {
    # 위 정보줄
    'hud-full':        ((0, 0, 704, 122), True),
    'hud-bar':         ((6, 2, 700, 66), True),
    'hud-round-chip':  ((14, 2, 92, 66), True),
    'hud-timer-tab':   ((6, 56, 102, 120), True),
    'hud-heart':       ((222, 16, 266, 56), True),
    'hud-hp-bar':      ((222, 14, 404, 56), True),
    'hud-coin':        ((428, 12, 468, 58), True),
    'hud-speed':       ((598, 6, 700, 94), True),
    # 맵 위 배치 칸 (빈 칸 하나)
    'map-tile':        ((146, 393, 227, 474), True),
    # 아래 트레이
    'tray-full':       ((0, 1048, 704, 1524), False),
    'tray-panel':      ((8, 1058, 548, 1510), False),
    'card-spear':      ((24, 1078, 186, 1278), False),
    'card-archer':     ((196, 1074, 358, 1278), False),
    'card-gunner':     ((367, 1078, 530, 1278), False),
    'card-cavalry':    ((24, 1288, 186, 1488), False),
    'card-navy':       ((196, 1288, 358, 1488), False),
    'card-mystic':     ((367, 1288, 530, 1488), False),
    'tab-barracks':    ((555, 1061, 695, 1133), False),
    'tab-upgrade':     ((555, 1137, 695, 1208), False),
    'tab-relic':       ((555, 1212, 695, 1284), False),
    'tab-effect':      ((555, 1288, 695, 1360), False),
    'button-draw':     ((555, 1360, 704, 1508), False),
}


def grass_to_alpha(rgb):
    """가장자리에서 이어진 풀색을 투명하게."""
    a = rgb.astype(int)
    ref = np.array([123, 161, 72])
    near = (np.abs(a - ref).sum(2) < 45) | ((a[..., 1] > a[..., 0] + 20) & (a[..., 1] > a[..., 2] + 50))
    m = near.astype(np.uint8)
    h, w = m.shape
    lab_n, lab = cv2.connectedComponents(m, connectivity=4)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border)) & (m > 0)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    return np.dstack([rgb, alpha])


def main():
    os.makedirs(OUT, exist_ok=True)
    src = np.asarray(Image.open(SRC).convert('RGB'))
    saved = []
    for name, ((x0, y0, x1, y1), grass) in PIECES.items():
        box = [round(v * K) for v in (x0, y0, x1, y1)]
        piece = src[box[1]:box[3], box[0]:box[2]]
        arr = grass_to_alpha(piece) if grass else piece
        if name == 'hud-full':   # 정보줄 아래로 삐져나온 궁 지붕 끝 빼기 (가운데 아래쪽)
            arr[round(68 * K):, round(106 * K):round(594 * K), 3] = 0
        im = Image.fromarray(arr)
        if grass:
            bb = im.getbbox()
            if bb: im = im.crop(bb)
        im.save(os.path.join(OUT, f'{name}.png'))
        saved.append((name, im))
        print(name, im.size)

    # 한눈에 보기 (체크무늬 위)
    pad, cols, cell = 16, 4, 300
    rows = (len(saved) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * (cell + pad) + pad, rows * (cell + 40 + pad) + pad), (40, 33, 28, 255))
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(saved):
        cx, cy = pad + (i % cols) * (cell + pad), pad + (i // cols) * (cell + 40 + pad)
        t = im.copy(); t.thumbnail((cell, cell))
        chk = Image.new('RGBA', t.size, (200, 200, 200, 255))
        cd = ImageDraw.Draw(chk)
        for yy in range(0, t.height, 12):
            for xx in range(0, t.width, 12):
                if (xx // 12 + yy // 12) % 2: cd.rectangle([xx, yy, xx + 11, yy + 11], fill=(235, 235, 235, 255))
        chk.alpha_composite(t.convert('RGBA'))
        sheet.alpha_composite(chk, (cx, cy))
        d.text((cx, cy + cell + 8), f'{name}  {im.width}x{im.height}', fill=(255, 246, 224, 255))
    sheet.convert('RGB').save(PREV)


if __name__ == '__main__':
    main()
