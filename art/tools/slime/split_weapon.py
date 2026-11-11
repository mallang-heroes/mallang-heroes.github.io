"""장비 슬라임에서 무기(창)를 따로 떼어 내기 → 유니티에서 무기만 움직여 찌르는 공격 모션.

입력: art/source/gemini/slime-base/dots/<병과>-<등급>.png (그림 왼쪽에 세워 든 창)
출력: art/source/gemini/slime-base/parts/<병과>-<등급>-body.png    몸(+모자, 손)
      art/source/gemini/slime-base/parts/<병과>-<등급>-weapon.png  무기만
      art/source/gemini/slime-base/parts/parts.json  무기 쥔 자리(grip, 도트, 그림 왼쪽 위 기준)
      art/preview/slime-base/<병과>-parts.png        빨강 = 무기로 잡힌 부분 (확인용)
찾는 법: 왼쪽 30% 안에서 불투명 칸이 가장 많은 열 = 자루. 몸 윗줄보다 위는 자루와 이어진 덩어리 전체(날·술·장식),
몸 높이에서는 자루 ±2열 중 몸색이 아닌 칸만 무기로 본다.
실행: python3 art/tools/slime/split_weapon.py spear
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
DOTS = os.path.join(ROOT, 'art/source/gemini/slime-base/dots')
PARTS = os.path.join(ROOT, 'art/source/gemini/slime-base/parts')
PREV = os.path.join(ROOT, 'art/preview/slime-base')
BODY = np.array((218, 108, 85))
RANKS = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu']


def split(a):
    op = a[..., 3] > 0
    c = a[..., :3].astype(int)
    H, W = op.shape
    body = op & (c[..., 0] > 165) & ((np.abs(c - BODY).sum(2) < 120) | (np.abs(c - BODY * 0.8).sum(2) < 90))
    counts = op[:, :max(3, int(W * 0.3))].sum(0)
    sx = int(np.argmax(counts))
    # 몸 윗줄: 자루 오른쪽으로 몸색이 넓게 시작하는 줄
    body_rows = np.where(body[:, sx + 3:].sum(1) > W * 0.25)[0]
    top = body_rows[0] if len(body_rows) else H
    weapon = np.zeros_like(op)
    # 몸 위쪽: 자루 열을 지나는 덩어리 전체
    upper = op.copy(); upper[top:] = False
    lab, n = ndimage.label(upper, structure=np.ones((3, 3)))
    ids = set(np.unique(lab[:top, max(0, sx - 1):sx + 2])) - {0}
    for i in ids:
        weapon |= lab == i
    # 몸 높이: 자루 ±2열에서 몸색이 아닌 칸
    band = np.zeros_like(op); band[top:, max(0, sx - 2):sx + 3] = True
    weapon |= band & op & ~body
    # 무기 폭 = 창만 있는 맨 윗부분(모자·투구보다 위)의 폭. 그보다 자루에서 멀리 있는 칸(모자 챙 등)은 무기 아님
    other = op.copy(); other[:, max(0, sx - 8):sx + 9] = False
    alone_rows = [y for y in range(H) if op[y].any() and not other[:y + 1].any()]
    half = 2
    for y in alone_rows:
        xs = np.where(op[y])[0]
        half = max(half, int(max(abs(xs.min() - sx), abs(xs.max() - sx))))
    keep = np.zeros_like(op); keep[:, max(0, sx - half):sx + half + 1] = True
    weapon &= keep
    # 쥔 자리: 몸 높이 중간쯤 자루
    rows = np.where(weapon[top:, sx])[0]
    grip_y = top + (rows[len(rows) // 2] if len(rows) else (H - top) // 2)
    return weapon, (sx + 0.5, grip_y + 0.5), top, sx, half


def main(branch='spear'):
    os.makedirs(PARTS, exist_ok=True)
    pj = os.path.join(PARTS, 'parts.json')
    meta = json.load(open(pj, encoding='utf-8')) if os.path.exists(pj) else {}
    previews = []
    for rk in RANKS:
        a = np.asarray(Image.open(os.path.join(DOTS, f'{branch}-{rk}.png'))).copy()
        w, grip, top, sx, half = split(a)
        body = a.copy(); body[w, 3] = 0
        # 창을 떼어 낸 자리(몸 왼쪽이 세로로 잘림)를 몸 오른쪽을 좌우로 뒤집어 채운다 (슬라임 몸은 좌우 대칭)
        feet = json.load(open(os.path.join(DOTS, 'feet.json'), encoding='utf-8'))
        cx = feet[f'{branch}-{rk}'][0]          # 발 x = 몸 가운데
        H, W = w.shape
        # 채울 줄: 창 말고도 다른 그림(모자·몸)이 있는 줄 (창끝·술만 있는 줄은 채우지 않음)
        rest = (a[..., 3] > 0) & ~w
        rest_rows = rest[:, min(W, sx + half + 1):].any(1)
        for y, x in zip(*np.where(w)):
            if not rest_rows[y]: continue
            mx = int(round(2 * cx - x - 1))
            if 0 <= mx < W and a[y, mx, 3] > 0 and not w[y, mx]:
                body[y, x] = a[y, mx]
        # 떼어 내고 남은 창 부스러기(몸과 안 붙은 작은 점) 지우기
        bl, bn = ndimage.label(body[..., 3] > 0, structure=np.ones((3, 3)))
        if bn > 1:
            sizes = ndimage.sum(np.ones_like(bl), bl, range(1, bn + 1))
            keep_id = 1 + int(np.argmax(sizes))
            body[(bl != keep_id) & (bl > 0), 3] = 0
        weap = a.copy(); weap[~w, 3] = 0
        Image.fromarray(body).save(os.path.join(PARTS, f'{branch}-{rk}-body.png'))
        Image.fromarray(weap).save(os.path.join(PARTS, f'{branch}-{rk}-weapon.png'))
        tip_row = int(np.where(w.any(1))[0][0])
        meta[f'{branch}-{rk}'] = {'grip': [float(grip[0]), float(grip[1])], 'tip': float(grip[1] - tip_row)}   # tip = 쥔 자리→창끝 길이(도트)
        pv = a.copy(); pv[w, :3] = (255, 0, 0)
        previews.append(Image.fromarray(pv))
        print(rk, 'grip', grip, 'weapon px', int(w.sum()))
    json.dump(meta, open(pj, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    Wt = sum(p.width + 3 for p in previews); Ht = max(p.height for p in previews) + 2
    cv = Image.new('RGBA', (Wt, Ht), (123, 161, 72, 255)); x = 1
    for p in previews:
        cv.alpha_composite(p, (x, Ht - 1 - p.height)); x += p.width + 3
    cv.resize((Wt * 10, Ht * 10), Image.NEAREST).save(os.path.join(PREV, f'{branch}-parts.png'))


if __name__ == '__main__':
    main(*(sys.argv[1:] or ['spear']))
