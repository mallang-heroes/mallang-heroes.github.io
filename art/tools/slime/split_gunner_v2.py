"""포수 v2 (창병 스크립트 기반): 원본 그림에서 '두 손+창'을 직접 떼고, 몸의 빈자리를 메움.
python3 art/tools/slime/split_spear_v2.py  → spear-rN-body.png / spear-rN-weapon.png (+ rig json)"""
import json, os, sys
import numpy as np, cv2
from PIL import Image
from scipy import ndimage
D = 'art/source/gemini/slime-v2'
# 좌표: cut 이미지 기준 (r1은 2배로 키운 크기 기준)
RIG = {   # 원본(1024 폭) 좌표: 자루 끝 · 총구 가운데 · 손(위·아래)
    1: dict(butt=(110, 600), tip=(935, 255), hands=[(600, 385), (295, 490)]),
    2: dict(butt=(110, 688), tip=(935, 340), hands=[(605, 470), (290, 580)]),
    3: dict(butt=(110, 598), tip=(935, 250), hands=[(600, 380), (290, 490)]),
    4: dict(butt=(105, 688), tip=(935, 320), hands=[(605, 465), (290, 580)]),
}
HAND_R, SHAFT_HW, BLADE_HW = 50, 17, 62


def seg_dist(xx, yy, a, b):
    a = np.array(a, float); b = np.array(b, float); d = b - a
    t = ((xx - a[0]) * d[0] + (yy - a[1]) * d[1]) / (d @ d)
    tc = np.clip(t, 0, 1)
    return np.hypot(xx - (a[0] + tc*d[0]), yy - (a[1] + tc*d[1])), t


def fit_clean(path, sil, size):
    sys.path.insert(0, 'art/tools/slime')
    from keying import key_out_purple, components
    g = sorted(components(key_out_purple(path), merge=0), key=lambda c: -c[2])[0][1]   # 왼쪽 조각 = 몸
    ga = np.asarray(g)[..., 3] > 128
    ys, xs = np.where(sil); gy, gx = np.where(ga)
    k = ((xs.max()-xs.min())/(gx.max()-gx.min()) + (ys.max()-ys.min())/(gy.max()-gy.min())) / 2
    g2 = g.resize((round(g.width*k), round(g.height*k)), Image.LANCZOS)
    a2 = np.asarray(g2)[..., 3] > 128; y2, x2 = np.where(a2)
    ox = round((xs.min()+xs.max())/2 - (x2.min()+x2.max())/2); oy = ys.max() - y2.max()
    out = Image.new('RGBA', size); out.alpha_composite(g2, (ox, oy))
    return out


def erase_disk(im, c, rad):
    a = np.asarray(im).copy(); h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    m = (np.hypot(xx - c[0] + 4, yy - c[1] - 6) <= rad) & (a[..., 3] > 0)
    rgb = cv2.inpaint(np.ascontiguousarray(a[..., :3]), (m*255).astype(np.uint8), 15, cv2.INPAINT_TELEA)
    rgb = np.where(m[..., None], cv2.GaussianBlur(rgb, (0, 0), 3), rgb)
    a[..., :3] = rgb
    return Image.fromarray(a, 'RGBA')


def split(r):
    sys.path.insert(0, 'art/tools/slime')
    from keying import key_out_purple
    im = key_out_purple(f'{D}/gunner-r{r}-src.png')
    a = np.asarray(im).copy()
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    g = RIG[r]
    dist, t = seg_dist(xx, yy, g['butt'], g['tip'])
    weapon = dist <= SHAFT_HW
    rr, gg, bb_ = [a[..., i].astype(int) for i in range(3)]
    purple = (bb_ > gg + 40) & (rr > gg + 15) & (bb_ > 110)
    weapon |= (dist <= BLADE_HW) & (t > .6) & ~purple   # 청동 총신(보라 몸은 빼고)
    for hx, hy in g['hands']:
        weapon |= np.hypot(xx - hx, yy - hy) <= HAND_R
    weapon &= a[..., 3] > 0
    # 무기 레이어
    wa = a.copy(); wa[..., 3] = np.where(weapon, a[..., 3], 0)
    # 몸 실루엣: 무기 뺀 나머지를 닫고 구멍 메움
    rest = ndimage.binary_opening((a[..., 3] > 128) & ~weapon, iterations=8)   # 창 테두리 찌꺼기 제거
    lab, n = ndimage.label(rest)
    cnt = np.bincount(lab.ravel()); cnt[0] = 0
    big = np.isin(lab, np.where(cnt > cnt.max()*.03)[0])   # 창대에 잘린 위·아래 몸 모두
    # 무기가 덮던 자리만 메움(손이 몸 테두리에 걸친 곳 포함). 깃털·모자 사이는 안 메움
    sil = big | (ndimage.binary_closing(big, iterations=45) & weapon)
    sil = ndimage.binary_fill_holes(sil)
    # 창이 몸 테두리를 지나던 곳의 실루엣을 둥글게 다듬음
    near = ndimage.binary_dilation(weapon, iterations=25)
    smooth = ndimage.gaussian_filter(ndimage.binary_closing(sil, iterations=30).astype(float), 9) > .5
    sil = np.where(near, smooth, sil)
    hole = sil & ndimage.binary_dilation(weapon | (a[..., 3] <= 128), iterations=3)
    lum = a[..., :3].astype(float) @ [.3, .59, .11]
    edge = sil & ~ndimage.binary_erosion(sil, iterations=7)          # 몸 테두리 띠
    dark_near = ndimage.binary_dilation(hole, iterations=8) & (lum < 90) & ~edge
    fillm = (hole | dark_near) & ~edge | (hole & edge)
    rgb = cv2.inpaint(np.ascontiguousarray(a[..., :3]), (fillm*255).astype(np.uint8), 12, cv2.INPAINT_TELEA)
    # 메운 자리의 몸 테두리는 외곽선 색으로 다시 그음
    rim = hole & ~ndimage.binary_erosion(sil, iterations=5)
    rgb[rim] = [74, 24, 26]
    rgb = np.where((fillm & ~rim)[..., None], cv2.GaussianBlur(rgb, (0, 0), 2.5), rgb)
    ba = np.dstack([rgb, np.where(sil, np.maximum(a[..., 3], 255*hole), 0)]).astype(np.uint8)
    ba[..., 3] = np.where(sil, np.where(hole, 255, a[..., 3]), 0)
    # 몸 중심(무기 제외) — 열 기준
    cols = sil.sum(0); xs = np.where(cols > cols.max()*.35)[0]
    rows = sil.sum(1); ys = np.where(rows > rows.max()*.30)[0]
    meta = dict(size=[w, h], body_cx=int((xs[0]+xs[-1])/2), body_bottom=int(ys[-1]),
                butt=g['butt'], tip=g['tip'], hands=g['hands'])
    body = Image.fromarray(ba, 'RGBA')
    clean = f'{D}/gunner-r{r}-parts-try1.png'   # 제미나이가 그려 준 '손·창 없는 몸'이 있으면 그걸 맞춰서 씀
    if os.path.exists(clean):
        body = fit_clean(clean, sil, (w, h))
        meta['body_src'] = os.path.basename(clean)
    body.save(f'{D}/gunner-r{r}-body.png')
    Image.fromarray(wa, 'RGBA').save(f'{D}/gunner-r{r}-weapon.png')
    return meta


if __name__ == '__main__':
    meta = {r: split(r) for r in RIG}
    json.dump(meta, open(f'{D}/gunner-rig.json', 'w'), indent=1)
    for r, m in meta.items(): print(r, m['body_cx'], m['body_bottom'], m['size'])
