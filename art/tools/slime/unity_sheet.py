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
# 세트: unity = 큰 견본으로 뽑은 것(2026-11-11 첫 시도), base = 맵에 맞춘 기본 슬라임 + 장비 (확정 방향)
SETS = {
    'unity': ('art/source/gemini/slime-unity', 'art/preview/slime-unity'),
    'base': ('art/source/gemini/slime-base', 'art/preview/slime-base'),
}
SRC = DOTS = PREV = None


def use_set(name):
    global SRC, DOTS, PREV
    SRC = os.path.join(ROOT, SETS[name][0])
    DOTS = os.path.join(SRC, 'dots')
    PREV = os.path.join(ROOT, SETS[name][1])


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


def split_by_bodies(d, body_rgb):
    """몸(몸색 덩어리) 4개를 먼저 찾고, 창·모자 같은 나머지 덩어리를 가장 가까운 몸에 붙여 4마리로 나눈다.
    (창이 옆 슬라임과 가까워 빈 열로는 못 나눌 때)"""
    from scipy import ndimage
    a = d[..., 3] > 0
    c = d[..., :3].astype(int)
    base = np.array(body_rgb)
    body = a & ((np.abs(c - base).sum(2) < 120) | (np.abs(c - base * 0.8).sum(2) < 90))
    lab, n = ndimage.label(body)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    top = sorted(np.argsort(sizes)[-4:] + 1, key=lambda i: ndimage.center_of_mass(lab == i)[1])
    spans = []
    for i in top:
        xs = np.where((lab == i).any(0))[0]
        spans.append((xs.min(), xs.max()))
    owner = np.full(a.shape, -1)
    alab, an = ndimage.label(a, structure=np.ones((3, 3)))
    for k in range(1, an + 1):
        m = alab == k
        if m.sum() < 3: continue
        xs = np.where(m.any(0))[0]
        cx = (xs.min() + xs.max()) / 2
        # 몸을 포함하면 그 몸, 아니면 가로로 가장 가까운 몸
        inside = [j for j, i in enumerate(top) if (m & (lab == i)).any()]
        if inside:
            j = inside[0]
        else:
            j = int(np.argmin([0 if lo <= cx <= hi else min(abs(cx - lo), abs(cx - hi)) for lo, hi in spans]))
        owner[m] = j
    parts = []
    for j, i in enumerate(top):
        m = owner == j
        ys, xs = np.where(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        piece = d[y0:y1, x0:x1].copy()
        piece[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0)
        bm = (lab == i)[y0:y1, x0:x1]
        rows = np.where(bm.sum(1) >= 3)[0]
        fy = rows[-1] + 1
        widest = max(rows, key=lambda r: bm[r].sum())
        wc = np.where(bm[widest])[0]
        parts.append((piece, ((wc[0] + wc[-1] + 1) / 2, fy), wc[-1] - wc[0] + 1, (y0, x0)))
    return parts


def main(branch='spear', set_name='unity'):
    use_set(set_name)
    body_key = 'base' if set_name == 'base' else branch
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
    parts = split_by_bodies(d, sp.BODY[body_key]) if set_name == 'base' else sp.split(d, sp.BODY[body_key])
    os.makedirs(DOTS, exist_ok=True); os.makedirs(PREV, exist_ok=True)
    fp = os.path.join(DOTS, 'feet.json')
    feet = json.load(open(fp, encoding='utf-8')) if os.path.exists(fp) else {}
    pieces = []
    for (piece, foot, bw, off), rk in zip(parts, sp.RANKS):
        piece = sp.clean_piece(piece, sp.BODY[body_key], MAP_OUTLINE if set_name == 'base' or branch == 'base' else (42, 33, 28))
        foot = (foot[0] + 1, foot[1] + 1)
        if set_name == 'base' and branch != 'base' and f'base-{rk}' in feet:
            # 장비를 얹은 그림은 모자·띠 때문에 몸 폭을 재기 어렵다 → 기본 슬라임 몸 폭을 도트 크기 비율로 옮겨 씀
            b = feet[f'base-{rk}']
            bw = b[2] * b[3] / P
        feet[f'{branch}-{rk}'] = [float(foot[0]), float(foot[1]), float(bw), float(P)]   # 발 x, 발 y, 몸 폭(도트), 원본 도트 크기(px)
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
    # 예: python3 art/tools/slime/unity_sheet.py spear base
    main(*(sys.argv[1:] or ['spear']))
