"""카툰 유닛 파츠 시트(위 줄 = 창 없는 몸 4, 아래 줄 = 창만 4, 하늘색 배경) → 몸·무기 따로 (2026-11-11).

  공격할 때 창만 찌르려고 몸과 창을 따로 받는다. 배경 지우기는 cartoon_sheet.py와 같다.
  한 시트는 한 배율(몸 폭 합 = 게임 몸 폭 합 30+36+42+48)로 @2x까지 줄인다.
  쥔 자리: 창은 몸 왼쪽(화면 왼쪽) 작은 손에 쥔다 — 손 = 몸 아래쪽 절반에서 가장 왼쪽으로 튀어나온 곳.
           창에서 쥐는 곳 = 창 아래 끝이 발보다 살짝 위에 오는 곳.
출력: art/source/gemini/unit-cartoon/parts/<병과>-<등급>-body.png, -weapon.png,
      parts.json {name: {foot:[x,y], hand:[x,y] (몸 그림 px), grip:[x,y], tip:[x,y] (무기 그림 px)}} — 모두 @2x px
실행: python3 art/tools/slime/cartoon_parts.py art/source/gemini/unit-cartoon/spear-parts-v1.png spear
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from cartoon_sheet import key_cyan, TIERS, BODY, S  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'art/source/gemini/unit-cartoon/parts')


def split_cols(solid, n=4):
    cols = solid.any(axis=0)
    runs, x, w = [], 0, len(cols)
    while x < w:
        if cols[x]:
            x0 = x
            while x < w and cols[x]: x += 1
            if x - x0 > 5: runs.append((x0, x))
        x += 1
    if len(runs) == n:                      # 깔끔하게 떨어져 있으면 빈 열로
        return runs
    cnt = ndimage.uniform_filter1d(solid.sum(axis=0).astype(float), 5)
    xs = np.where(cnt > 0)[0]; left, right = xs[0], xs[-1] + 1
    cuts = []
    for x in np.argsort(cnt[left:right], kind='stable') + left:
        if x - left < 40 or right - x < 40: continue
        if all(abs(x - c) > 120 for c in cuts): cuts.append(int(x))
        if len(cuts) == n - 1: break
    e = [left] + sorted(cuts) + [right]
    return list(zip(e[:-1], e[1:]))


def piece(rgb, alpha, solid, y0, y1, x0, x1):
    m = solid[y0:y1, x0:x1]
    ml, mn = ndimage.label(m)
    main = ml == 1 + int(np.argmax(ndimage.sum(m, ml, range(1, mn + 1))))
    a = alpha[y0:y1, x0:x1] * ndimage.binary_dilation(main, iterations=3)
    ys, xs = np.where(main)
    by0, by1, bx0, bx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    pad = 4
    c = np.zeros((by1 - by0 + 2 * pad, bx1 - bx0 + 2 * pad, 4), np.float32)
    c[pad:-pad, pad:-pad, :3] = rgb[y0 + by0:y0 + by1, x0 + bx0:x0 + bx1]
    c[pad:-pad, pad:-pad, 3] = a[by0:by1, bx0:bx1] * 255
    mask = np.zeros(c.shape[:2], bool); mask[pad:-pad, pad:-pad] = main[by0:by1, bx0:bx1]
    return c, mask


def shrink(c, k):
    pm = c.copy(); pm[..., :3] *= c[..., 3:4] / 255
    im = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), 'RGBA')
    sm = np.asarray(im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)).astype(np.float32)
    al = sm[..., 3:4]
    sm[..., :3] = np.where(al > 0, sm[..., :3] * 255 / np.maximum(al, 1), 0)
    return Image.fromarray(np.clip(sm, 0, 255).astype(np.uint8), 'RGBA')


def main(path, branch):
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    rgb, alpha = key_cyan(a)
    h, w = alpha.shape
    lab, n = ndimage.label(alpha > .1)
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl[0].start > h * .75 and sl[1].start > w * .85 and (sl[0].stop - sl[0].start) < 80 and (sl[1].stop - sl[1].start) < 80:
            alpha[lab == i + 1] = 0
    solid = alpha > .5
    rows = solid.any(axis=1)
    # 위·아래 줄 사이 빈 줄 (가운데 근처에서 가장 긴 빈 구간)
    ys = np.where(rows)[0]
    gaps = [(y, y2) for y, y2 in zip(ys[:-1], ys[1:]) if y2 - y > 8]
    gy = max(gaps, key=lambda g: g[1] - g[0])
    top, bot = (ys[0], gy[0] + 1), (gy[1], ys[-1] + 1)
    bodies = [piece(rgb, alpha, solid, *top, x0, x1) for x0, x1 in split_cols(solid[top[0]:top[1]])]
    spears = [piece(rgb, alpha, solid, *bot, x0, x1) for x0, x1 in split_cols(solid[bot[0]:bot[1]])]
    assert len(bodies) == 4 and len(spears) == 4
    info = []
    for c, m in bodies:
        yy, xx = np.where(m)
        fy = yy.max() + 1
        width = int(m[fy - 30].sum())
        fx = xx[yy >= fy - 15].mean() + .5
        # 왼손: 몸 아래쪽 절반에서 가장 왼쪽
        low = yy > yy.min() + (fy - yy.min()) * .45
        hx = xx[low].min()
        hy = yy[low][xx[low] <= hx + 2].mean()
        # 손 크기: 손 자리 세로줄에서 몸이 이어진 길이의 절반
        col = m[:, hx + 6]; ry = int(round(hy))
        y_a = ry
        while y_a > 0 and col[y_a - 1]: y_a -= 1
        y_b = ry
        while y_b < len(col) - 1 and col[y_b + 1]: y_b += 1
        nub = max(4, (y_b - y_a + 1) / 2)
        # 팔 색: 손 안쪽 몸 색(가운데값), 외곽선: 손 둘레의 가장 어두운 색
        cy0, cx0 = int(hy), int(hx + 6)
        rgbp = c[..., :3]; al = c[..., 3] > 250
        win = (slice(max(0, cy0 - 4), cy0 + 5), slice(cx0 + 2, cx0 + 14))
        body_col = np.median(rgbp[win][al[win]], axis=0)
        ring = (slice(max(0, cy0 - 30), cy0 + 30), slice(max(0, cx0 - 12), cx0 + 10))
        px = rgbp[ring][al[ring]]
        lum = px.sum(axis=1)
        line_col = np.median(px[lum <= np.percentile(lum, 6)], axis=0)
        info.append((fx, fy, width, hx + 6, hy, nub, body_col, line_col))
    k = sum(BODY) * S / sum(i[2] for i in info)   # 몸 폭 합 기준 한 배율
    os.makedirs(OUT, exist_ok=True)
    pj = os.path.join(OUT, 'parts.json')
    parts = json.load(open(pj)) if os.path.exists(pj) else {}
    for t in range(4):
        name = f'{branch}-{TIERS[t]}'
        (bc, bm), (sc, smk) = bodies[t], spears[t]
        fx, fy, width, hx, hy, nub, body_col, line_col = info[t]
        shrink(bc, k).save(os.path.join(OUT, f'{name}-body.png'))
        shrink(sc, k).save(os.path.join(OUT, f'{name}-weapon.png'))
        yy, xx = np.where(smk)
        ty = yy.min(); tx = xx[yy <= ty + 3].mean() + .5
        # 창 아래 끝이 발(바닥)보다 살짝 위에 오도록 쥐는 곳을 정함 (창이 짧으면 창끝에서 30% 아래)
        gy_ = max(yy.max() - (fy - 8 - hy), ty + (yy.max() - ty) * .3)
        gx = xx[np.abs(yy - gy_) < 3].mean() + .5
        r = lambda v: round(float(v) * k, 2)
        parts[name] = {'foot': [r(fx), r(fy)], 'hand': [r(hx), r(hy)], 'grip': [r(gx), r(gy_)], 'tip': [r(tx), r(ty)],
                       'body': round(width * k / S, 1), 'nub': r(nub),
                       'color': [int(v) for v in body_col], 'line': [int(v) for v in line_col]}
        print(name, parts[name])
    json.dump(parts, open(pj, 'w'), indent=1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
