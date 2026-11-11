"""제미나이 유니티 시트(칸 4개, 큰 슬라임) → 도트 정리 → 유니티 새 유닛 그림(UnitsV2).

입력: art/source/gemini/slime-unity/<병과>-sheet.png
출력: art/source/gemini/slime-unity/dots/<병과>-<등급>.png   1도트 = 1px (투명, 외곽선 닫음)
      art/source/gemini/slime-unity/dots/feet.json             발 위치(도트)
      art/preview/slime-unity/<병과>-dots.png                  12배 확대 확인용
도트 크기는 외곽선 굵기에서 찾는다(진한 줄 길이의 최빈값). 얼굴은 큰 견본이라 다시 찍지 않는다.
실행: python3 art/tools/slime/unity_sheet.py spear
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import snap_pixel_slime as sp  # noqa: E402

ROOT = sp.ROOT
SRC = os.path.join(ROOT, 'art/source/gemini/slime-unity')
DOTS = os.path.join(SRC, 'dots')
PREV = os.path.join(ROOT, 'art/preview/slime-unity')


def dot_size(path):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    dark = a.sum(2) < 160
    runs = []
    for m in (dark, dark.T):
        for row in m:
            c = 0
            for v in row:
                if v: c += 1
                else:
                    if c >= 3: runs.append(c)
                    c = 0
    r = np.array([x for x in runs if x < 16])
    hist = np.bincount(r)
    p = int(np.argmax(hist[3:9])) + 3      # 외곽선 1도트 두께
    # 앞뒤 값으로 소수점 보정
    w = hist[p - 1:p + 2].astype(float)
    return p + (w[2] - w[0]) / max(1.0, w.sum()) 


MAP_OUTLINE = (60, 68, 70)   # 맵·궁 외곽선 청회색 #3C4446


def main(branch='spear'):
    path = os.path.join(SRC, f'{branch}-sheet.png')
    # 하늘색 배경 + 제미나이가 넣은 어두운 청록 그림자를 모두 순수 하늘색으로
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    bgm = (a[..., 1] > 140) & (a[..., 2] > 140) & (a[..., 0] < 120)
    a[bgm] = (0, 255, 255)
    os.makedirs(PREV, exist_ok=True)
    tmp = os.path.join(PREV, f'_{branch}-bg.png')
    Image.fromarray(a.astype(np.uint8)).save(tmp)
    P = round(dot_size(path), 2)
    d = sp.snap(tmp, P)
    os.remove(tmp)
    parts = sp.split(d, sp.BODY[branch])
    os.makedirs(DOTS, exist_ok=True); os.makedirs(PREV, exist_ok=True)
    fp = os.path.join(DOTS, 'feet.json')
    feet = json.load(open(fp, encoding='utf-8')) if os.path.exists(fp) else {}
    pieces = []
    for (piece, foot, bw, off), rk in zip(parts, sp.RANKS):
        piece = sp.clean_piece(piece, sp.BODY[branch], MAP_OUTLINE if branch == 'base' else (42, 33, 28))
        foot = (foot[0] + 1, foot[1] + 1)
        feet[f'{branch}-{rk}'] = [float(foot[0]), float(foot[1])]
        Image.fromarray(piece).save(os.path.join(DOTS, f'{branch}-{rk}.png'))
        pieces.append(Image.fromarray(piece))
        print(branch, rk, f'{piece.shape[1]}x{piece.shape[0]} dots, body {bw}, foot {foot}')
    json.dump(feet, open(fp, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    W = sum(p.width + 3 for p in pieces); H = max(p.height for p in pieces) + 2
    c = Image.new('RGBA', (W, H), (122, 160, 72, 255)); x = 1
    for p in pieces:
        c.alpha_composite(p, (x, H - 1 - p.height)); x += p.width + 3
    c.resize((W * 12, H * 12), Image.NEAREST).save(os.path.join(PREV, f'{branch}-dots.png'))


if __name__ == '__main__':
    main(*(sys.argv[1:] or ['spear']))
