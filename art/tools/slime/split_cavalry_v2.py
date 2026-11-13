"""기병 v2: 원본에서 '편곤+쥔 손'을 떼고 몸(말 포함)의 빈자리를 메움.
깨끗한 몸(cavalry-rN-parts-try1.png)이 있으면 원본에 맞춰 그걸 씀. 없으면 가로 방향 보간으로 메움(띠가 가로라 잘 이어짐).
→ cavalry-rN-body/weapon.png, cavalry-rig.json"""
import json, os, sys
import numpy as np, cv2
from PIL import Image
from scipy import ndimage
sys.path.insert(0, 'art/tools/slime')
from keying import key_out, components
D = 'art/source/gemini/slime-v2'
RIDER = dict(handle=((440, 430), (180, 180)), hands=[((322, 322), 40)], pivot=(372, 345), extra='left')
RIG = {
    1: dict(handle=((110, 600), (895, 232)), hands=[((600, 388), 44), ((290, 490), 44)], pivot=(445, 440), extra='right'),
    2: RIDER, 3: RIDER, 4: RIDER,
}


def seg(xx, yy, a, b):
    a = np.array(a, float); b = np.array(b, float); d = b - a
    t = ((xx-a[0])*d[0] + (yy-a[1])*d[1]) / (d @ d); tc = np.clip(t, 0, 1)
    return np.hypot(xx-(a[0]+tc*d[0]), yy-(a[1]+tc*d[1])), t


def row_fill(rgb, hole, sil):
    out = rgb.copy().astype(float)
    for y in np.where(hole.any(1))[0]:
        xs = np.where(hole[y])[0]
        good = np.where(sil[y] & ~hole[y])[0]
        if len(good) < 2: continue
        for x in xs:
            l = good[good < x]; r = good[good > x]
            if len(l) and len(r):
                xl, xr = l[-1], r[0]; w = (x - xl) / (xr - xl)
                out[y, x] = rgb[y, max(xl-2, 0)]*(1-w) + rgb[y, min(xr+2, rgb.shape[1]-1)]*w
            elif len(l): out[y, x] = rgb[y, l[-1]-2]
            elif len(r): out[y, x] = rgb[y, r[0]+2]
    return out.astype(np.uint8)


def fit_clean(path, orig_sil, size):
    g = sorted(components(key_out(path), merge=0), key=lambda c: -c[2])[0][1]
    ga = np.asarray(g)[..., 3] > 128
    oy, ox = np.where(orig_sil); gy, gx = np.where(ga)
    k = (oy.max() - oy.min()) / (gy.max() - gy.min())
    im = g.resize((round(g.width*k), round(g.height*k)), Image.LANCZOS)
    a2 = np.asarray(im)[..., 3] > 128; y2, x2 = np.where(a2)
    out = Image.new('RGBA', size); out.alpha_composite(im, (int(ox.max() - x2.max()), int(oy.max() - y2.max())))
    return out


def split(r):
    img = key_out(f'{D}/cavalry-r{r}-src.png'); a = np.asarray(img).copy(); h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    g = RIG[r]
    d, t = seg(xx, yy, *g['handle'])
    weapon = d <= (22 if r == 1 else 17)
    for (hx, hy), hr in g['hands']:
        weapon |= np.hypot(xx-hx, yy-hy) <= hr
    if g['extra'] == 'left':   weapon |= (xx < 245) & (yy < 470)          # 사슬·몽둥이(몸 왼쪽 위)
    if g['extra'] == 'right':  weapon |= (xx > 690)                      # 사슬·몽둥이(몸 오른쪽)
    weapon &= a[..., 3] > 0
    lab, n = ndimage.label(weapon & (a[..., 3] > 60))
    keep = np.unique(lab[(d <= 6) & (lab > 0)])                      # 자루에 이어진 조각만
    weapon = np.isin(lab, keep) | (weapon & (a[..., 3] <= 60) & ndimage.binary_dilation(np.isin(lab, keep), iterations=2))
    flail = weapon & (((xx < 245) & (yy < 470)) if g['extra'] == 'left' else (xx > 690))   # 사슬+몽둥이(따로 흔들림)
    # 자루 끝 쇠고리는 자루 쪽에 남김
    flail &= np.hypot(xx - g['handle'][1][0], yy - g['handle'][1][1]) > 14
    wa = a.copy(); wa[..., 3] = np.where(weapon & ~flail, a[..., 3], 0)
    Image.fromarray(wa, 'RGBA').save(f'{D}/cavalry-r{r}-weapon.png')
    fa = a.copy(); fa[..., 3] = np.where(flail, a[..., 3], 0)
    Image.fromarray(fa, 'RGBA').save(f'{D}/cavalry-r{r}-flail.png')
    rest = ndimage.binary_opening((a[..., 3] > 128) & ~weapon, iterations=3)
    lab, n = ndimage.label(rest); cnt = np.bincount(lab.ravel()); cnt[0] = 0
    rest = np.isin(lab, np.where(cnt > cnt.max()*.02)[0])
    sil = ndimage.binary_fill_holes(rest | (ndimage.binary_closing(rest, iterations=30) & ndimage.binary_dilation(weapon, iterations=3)))
    clean = f'{D}/cavalry-r{r}-parts-try1.png'
    if os.path.exists(clean):
        body = fit_clean(clean, a[..., 3] > 128, (w, h)); g = dict(g, body_src=os.path.basename(clean))
    else:
        hole = sil & ndimage.binary_dilation(weapon | (a[..., 3] <= 128), iterations=3)
        R, G, B = [a[..., i].astype(int) for i in range(3)]
        brownish = (R < 150) & (G < 110) & (B < 80) & (R > G)             # 자루 테두리 찌꺼기
        hole |= sil & ndimage.binary_dilation(hole, iterations=6) & brownish & ~ndimage.binary_dilation(~sil, iterations=8)
        tel = cv2.inpaint(np.ascontiguousarray(a[..., :3]), (hole*255).astype(np.uint8), 12, cv2.INPAINT_TELEA)
        orange = (R > 160) & (G > 90) & (B < 110) & (R - B > 80)
        band = np.zeros_like(hole)                                        # 띠가 지나는 줄만 가로 보간
        for y in np.where(hole.any(1))[0]:
            xs = np.where(hole[y])[0]; l, rr = xs.min() - 4, xs.max() + 4
            if 0 <= l and rr < w and sil[y, l] and sil[y, rr] and not orange[y, l] and not orange[y, rr]:
                band[y] = hole[y]
        rgb = np.where(band[..., None], row_fill(a[..., :3], hole, sil), tel)
        rgb = np.where(hole[..., None], cv2.GaussianBlur(rgb, (0, 0), 1.6), rgb)
        al = np.where(sil, np.where(hole, 255, a[..., 3]), 0)
        body = Image.fromarray(np.dstack([rgb, al]).astype(np.uint8), 'RGBA')
    body.save(f'{D}/cavalry-r{r}-body.png')
    s = np.asarray(body)[..., 3] > 128
    ys, xs = np.where(s)
    # 칸 가운데 기준: 말 탄 등급은 말+몸 전체 가운데, 군졸은 몸 가운데
    meta = dict(g, size=[w, h], body_cx=int((xs.min()+xs.max())/2), body_bottom=int(ys.max()), body_w=int(xs.max()-xs.min()))
    return meta


if __name__ == '__main__':
    meta = {r: split(r) for r in RIG}
    json.dump(meta, open(f'{D}/cavalry-rig.json', 'w'), indent=1)
    for r, m in meta.items(): print(r, m['body_cx'], m['body_w'], m['body_bottom'], m.get('body_src'))
