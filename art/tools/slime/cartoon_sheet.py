"""카툰 유닛 시트(제미나이, 하늘색 배경) → 유닛별 투명 PNG + 발 위치·몸 폭 (2026-11-11).

  하늘색 배경과 발밑 청록 그림자를 색상으로 지우고(가장자리 하늘색 번짐도 걷어 냄),
  오른쪽 아래 제미나이 반짝이 표시를 지운 뒤, 세로 빈 줄로 4칸을 나눈다.
  발 = 몸 바닥 가운데(창 자루 빼고), 몸 폭 = 창 자루를 깎아 낸 몸통의 가장 넓은 폭.
  게임에서는 몸 폭을 보드 30·36·42·48에 맞춰 줄인다 (Sprites.cs BaseBodyBoard).
  저장은 게임 크기의 @2x(보드 1 = 2px) — 맵과 같은 배율.
출력: art/source/gemini/unit-cartoon/units/<병과>-<등급>.png, feet.json {name: [발x, 발y, 몸폭(보드)]} (px @2x 기준)
실행: python3 art/tools/slime/cartoon_sheet.py art/source/gemini/unit-cartoon/spear-sheet-v1.png spear
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'art/source/gemini/unit-cartoon/units')
TIERS = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu']
BODY = [30, 36, 42, 48]
S = 2   # 보드 1 = 2px


def key_cyan(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.minimum(g, b) - r                     # 하늘색·청록일수록 큼
    alpha = np.clip((115.0 - m) / (115.0 - 45.0), 0, 1)
    # 하늘색 번짐 걷기: 배경색을 빼고 남은 색
    K = np.array([0.0, 255.0, 255.0])
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - alpha)[..., None] * K) / safe, 0, 255)
    edge = (alpha > 0) & (alpha < .98)
    lim = rgb[..., 0] + 40
    for c in (1, 2):
        rgb[..., c] = np.where(edge, np.minimum(rgb[..., c], np.maximum(lim, rgb[..., c] * .85)), rgb[..., c])
    return rgb, alpha


def main(path, branch):
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    rgb, alpha = key_cyan(a)
    h, w = alpha.shape
    # 제미나이 반짝이 (오른쪽 아래 작은 덩어리)
    lab, n = ndimage.label(alpha > .1)
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl[0].start > h * .75 and sl[1].start > w * .85 and (sl[0].stop - sl[0].start) < 80:
            alpha[lab == i + 1] = 0
    solid = alpha > .5
    # 칸 나누기: 열마다 채워진 칸 수가 가장 적은 골 3곳 (매듭·술이 살짝 닿아도 나뉘게)
    cnt = ndimage.uniform_filter1d(solid.sum(axis=0).astype(float), 5)
    xs = np.where(cnt > 0)[0]; left, right = xs[0], xs[-1] + 1
    cuts = []
    for x in np.argsort(cnt[left:right], kind='stable') + left:
        if x - left < 60 or right - x < 60: continue
        if all(abs(x - c) > 120 for c in cuts): cuts.append(int(x))
        if len(cuts) == 3: break
    edges = [left] + sorted(cuts) + [right]
    runs = list(zip(edges[:-1], edges[1:]))
    os.makedirs(OUT, exist_ok=True)
    feetp = os.path.join(OUT, 'feet.json')
    feet = json.load(open(feetp)) if os.path.exists(feetp) else {}
    info, alphas = [], []
    for t, (x0, x1) in enumerate(runs):
        m = solid[:, x0:x1].copy()
        # 이웃 칸에서 넘어온 조각 빼기: 이 칸에서 가장 큰 덩어리에 붙은 것만
        ml, mn = ndimage.label(m)
        main_id = 1 + int(np.argmax(ndimage.sum(m, ml, range(1, mn + 1))))
        m = ml == main_id
        alphas.append(alpha[:, x0:x1] * ndimage.binary_dilation(m, iterations=3))
        ys = np.where(m.any(axis=1))[0]; y0, y1 = ys[0], ys[-1] + 1
        # 몸통: 창 자루(가는 세로 막대)를 깎아 낸 가장 큰 덩어리
        core = ndimage.binary_opening(m, structure=np.ones((1, 31)))
        cl, cn = ndimage.label(core)
        big = 1 + int(np.argmax(ndimage.sum(core, cl, range(1, cn + 1))))
        body = cl == big
        bys, bxs = np.where(body)
        fy = bys.max() + 1
        width = int(body[fy - 30].sum())        # 바닥 조금 위 몸통 폭 (모자 챙·매듭 빼고)
        fx = bxs[bys >= fy - 15].mean() + .5
        info.append((t, x0, x1, y0, y1, fx, fy, width))
    # 한 시트는 한 배율로 줄인다 (외곽선 굵기가 등급마다 같게) — 몸 폭 합이 게임 몸 폭 합과 같도록
    k = sum(BODY) * S / sum(i[-1] for i in info)
    for t, x0, x1, y0, y1, fx, fy, width in info:
        pad = 4
        alpha_c = alphas[t]
        crop = np.zeros((y1 - y0 + 2 * pad, x1 - x0 + 2 * pad, 4), np.float32)
        crop[pad:-pad, pad:-pad, :3] = rgb[y0:y1, x0:x1]
        crop[pad:-pad, pad:-pad, 3] = alpha_c[y0:y1] * 255
        # 투명 부분 색이 번지지 않게 미리 곱해서 줄이기
        pm = crop.copy(); pm[..., :3] *= crop[..., 3:4] / 255
        im = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), 'RGBA')
        nw, nh = max(1, round(im.width * k)), max(1, round(im.height * k))
        sm = np.asarray(im.resize((nw, nh), Image.LANCZOS)).astype(np.float32)
        al = sm[..., 3:4]
        sm[..., :3] = np.where(al > 0, sm[..., :3] * 255 / np.maximum(al, 1), 0)
        out = Image.fromarray(np.clip(sm, 0, 255).astype(np.uint8), 'RGBA')
        name = f'{branch}-{TIERS[t]}'
        out.save(os.path.join(OUT, f'{name}.png'))
        feet[name] = [round((fx + pad) * k, 2), round((fy - y0 + pad) * k, 2), round(width * k / S, 1)]
        print(name, out.size, 'body board', round(width * k / S, 1), 'scale', round(k, 3))
    json.dump(feet, open(feetp, 'w'), indent=1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
