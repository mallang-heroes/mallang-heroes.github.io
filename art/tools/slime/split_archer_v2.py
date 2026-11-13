"""궁병 v2: 원본에서 화살·뒷손(시위 쥔 손)·시위를 떼고 몸(활·앞팔 포함)의 빈자리를 메움.
시위는 build 때 코드로 다시 그림. → archer-rN-body/arrow/hand.png, archer-rig.json"""
import json, sys
import numpy as np, cv2
from PIL import Image
from scipy import ndimage
sys.path.insert(0, 'art/tools/slime')
from keying import key_out, components
D = 'art/source/gemini/slime-v2'
# 대략 좌표(원본 1024×768) — 시위·화살은 아래에서 픽셀에 맞춰 다듬음
RIG = {
    1: dict(top=(602, 92), bot=(710, 672), nock=(335, 457), tip=(937, 290), hand=(285, 496)),
    2: dict(top=(615, 95), bot=(705, 675), nock=(337, 456), tip=(952, 300), hand=(288, 500)),
    3: dict(top=(605, 90), bot=(702, 670), nock=(335, 455), tip=(937, 290), hand=(288, 495)),
    4: dict(top=(610, 90), bot=(707, 675), nock=(340, 455), tip=(952, 297), hand=(285, 500)),
}


def seg(xx, yy, a, b):
    a = np.array(a, float); b = np.array(b, float); d = b - a
    t = ((xx-a[0])*d[0] + (yy-a[1])*d[1]) / (d @ d); tc = np.clip(t, 0, 1)
    return np.hypot(xx-(a[0]+tc*d[0]), yy-(a[1]+tc*d[1])), t


def refit(pts_mask, a, b):
    ys, xs = np.where(pts_mask)
    if len(xs) < 30:
        return a, b
    P = np.c_[xs, ys].astype(float); c = P.mean(0)
    u = np.linalg.svd(P - c)[2][0]
    proj = lambda p: tuple((c + u*((np.array(p, float)-c) @ u)).round().astype(int).tolist())
    return proj(a), proj(b)


def fit_clean(path, orig_sil, size, r, g):
    gi = key_out(path)
    comps = sorted(components(gi, merge=0), key=lambda c: -c[2])
    keep = np.zeros(np.asarray(gi).shape[:2], bool)
    a = np.asarray(gi).copy()
    for (x0, y0, x1, y1), im, area in comps:
        if area > 3000:
            keep[y0:y1, x0:x1] |= np.asarray(im)[..., 3] > 0
    a[..., 3] = np.where(keep, a[..., 3], 0)
    ga = a[..., 3] > 128
    oy, ox = np.where(orig_sil); gy, gx = np.where(ga)
    k = (oy.max() - oy.min()) / (gy.max() - gy.min())
    im = Image.fromarray(a, 'RGBA'); im = im.resize((round(im.width*k), round(im.height*k)), Image.LANCZOS)
    out = Image.new('RGBA', size); out.alpha_composite(im, (int(ox.min() - gx.min()*k), int(oy.min() - gy.min()*k)))
    b = np.asarray(out).copy()
    if r == 1:   # 군졸: 몸에 남은 뒷손 지우기
        hh, ww = b.shape[:2]; yy, xx = np.mgrid[0:hh, 0:ww]
        hx, hy = g['hand']
        m = (((xx-hx+2)/88)**2 + ((yy-hy+4)/60)**2 <= 1) & (b[..., 3] > 0)
        lum = b[..., :3].astype(float) @ [.3, .59, .11]
        m |= ndimage.binary_dilation(m, iterations=8) & (lum < 90) & (xx < hx+95) & (yy > hy-70)
        rgb = cv2.inpaint(np.ascontiguousarray(b[..., :3]), (m*255).astype(np.uint8), 18, cv2.INPAINT_TELEA)
        b[..., :3] = np.where(m[..., None], cv2.GaussianBlur(rgb, (0, 0), 3), rgb)
    return Image.fromarray(b, 'RGBA')


def snap_bow(b, p):
    R, G, B = [b[..., i].astype(int) for i in range(3)]
    bow = (b[..., 3] > 200) & (R < 140) & (G < 110) & (B < 90) & (R >= G)
    ys, xs = np.where(bow)
    d = np.hypot(xs - p[0], ys - p[1]); i = d.argmin()
    return (int(xs[i]), int(ys[i])) if d[i] < 45 else p


def split(r):
    img = key_out(f'{D}/archer-r{r}-src.png')
    a = np.asarray(img).copy(); h, w = a.shape[:2]
    rgb = a[..., :3].astype(int); R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    g = dict(RIG[r])
    # 화살대: 밝은 회백색
    d, t = seg(xx, yy, g['nock'], g['tip'])
    light = (R > 170) & (G > 170) & (B > 160) & (abs(R-G) < 35) & (a[..., 3] > 200)
    g['nock'], g['tip'] = refit(light & (d < 10) & (t > .15) & (t < .85), g['nock'], g['tip'])
    # 시위: 몸 위의 연한 베이지 선
    beige = (R > 160) & (G > 150) & (B > 90) & (R - B > 25) & (R - B < 110) & (G < R + 10)
    for k in ('top', 'bot'):
        d2, t2 = seg(xx, yy, g[k], g['nock'])
        g[k], _ = refit(beige & (d2 < 9) & (t2 > .2) & (t2 < .85), g[k], g['nock'])
    # 마스크
    d, t = seg(xx, yy, g['nock'], g['tip'])
    green = (G > R + 25) & (G > B + 25)
    arrow = ((d <= 9) | ((d <= 27) & (t < .2)) | ((d <= 30) & (t > .88))) & ~green
    hx, hy = g['hand']
    hand = ((xx-hx)/80)**2 + ((yy-hy)/56)**2 <= 1
    string = np.zeros_like(hand)
    meet = RIG[r]['nock']
    for k in ('top', 'bot'):
        d2, t2 = seg(xx, yy, RIG[r][k], meet)
        string |= (d2 <= 4)
        string |= ndimage.binary_dilation(beige & (d2 < 16), iterations=3)   # 실제 시위 픽셀
    lum = rgb @ [.3, .59, .11]
    ring = ndimage.binary_dilation(hand, iterations=14) & ~hand
    hand_x = hand | (ring & (lum < 95) & ndimage.binary_dilation(hand, iterations=14) & (xx < hx))  # 손에 붙은 팔 선
    vis = a[..., 3] > 0
    arrow &= vis; hand &= vis
    cut = arrow | hand_x | string
    # 떼어 낼 조각들
    for name, m in (('arrow', arrow & ~hand | (arrow & hand & light)), ('hand', hand & ~(arrow & light))):
        o = a.copy(); o[..., 3] = np.where(m, a[..., 3], 0)
        Image.fromarray(o, 'RGBA').save(f'{D}/archer-r{r}-{name}.png')
    # 몸(활·앞팔 포함): 빈자리 메움
    rest = (a[..., 3] > 128) & ~cut
    rest = ndimage.binary_opening(rest, iterations=2)
    lab, n = ndimage.label(rest); cnt = np.bincount(lab.ravel()); cnt[0] = 0
    rest = np.isin(lab, np.where(cnt > 2000)[0])     # 시위 찌꺼기 같은 작은 조각 버림
    sil = ndimage.binary_fill_holes(rest | (ndimage.binary_closing(rest, iterations=30) & ndimage.binary_dilation(cut, iterations=3)))
    hole = sil & ndimage.binary_dilation(cut | (a[..., 3] <= 128), iterations=2)
    edge = sil & ~ndimage.binary_erosion(sil, iterations=7)
    dark_near = ndimage.binary_dilation(hole, iterations=6) & (lum < 90) & ~edge
    fm = (hole | dark_near) & sil
    fill = cv2.inpaint(np.ascontiguousarray(a[..., :3]), (fm*255).astype(np.uint8), 14, cv2.INPAINT_TELEA)
    hole = fm
    fill = np.where(hole[..., None], cv2.GaussianBlur(fill, (0, 0), 1.8), fill)
    body = np.dstack([fill, np.where(sil, np.where(hole, 255, a[..., 3]), 0)]).astype(np.uint8)
    import os
    clean = f'{D}/archer-r{r}-clean-try1.png'   # 제미나이가 화살·시위·뒷손을 지워 그린 몸(활·앞팔 포함)
    if os.path.exists(clean):
        body = fit_clean(clean, a[..., 3] > 128, (w, h), r, g)
        sil = np.asarray(body)[..., 3] > 128
        g['body_src'] = os.path.basename(clean)
        g['top'], g['bot'] = snap_bow(np.asarray(body), g['top']), snap_bow(np.asarray(body), g['bot'])
        Image.fromarray(np.asarray(body), 'RGBA').save(f'{D}/archer-r{r}-body.png')
    else:
        Image.fromarray(body, 'RGBA').save(f'{D}/archer-r{r}-body.png')
    # 몸 가운데(활·팔 제외): 몸통 열 기준
    bimg = np.asarray(Image.open(f'{D}/archer-r{r}-body.png'))
    R_, G_, B_ = [bimg[..., i].astype(int) for i in range(3)]
    bowm = (bimg[..., 3] > 200) & (R_ < 150) & (G_ < 120) & (B_ < 100) & (R_ >= G_) & (R_ - B_ > 15)
    lab, n = ndimage.label(ndimage.binary_closing(bowm, iterations=3))
    tall = [i for i, sl in enumerate(ndimage.find_objects(lab), 1) if sl[0].stop - sl[0].start > 300]
    bowm = np.isin(lab, tall)                         # 세로로 긴 갈색 덩어리 = 활
    core = ndimage.binary_opening((bimg[..., 3] > 128) & ~ndimage.binary_dilation(bowm, iterations=4), iterations=25)
    rows = core.sum(1); ys = np.where(rows > rows.max()*.3)[0]
    y0, y1 = ys[0], ys[-1]
    los, his = [], []
    for y in range(int(y0 + (y1-y0)*.7), int(y0 + (y1-y0)*.92)):
        xs_ = np.where(core[y])[0]
        if not len(xs_): continue
        run_end = xs_[0] + np.argmax(np.r_[np.diff(xs_) > 1, True])   # 왼쪽부터 끊기기 전까지
        los.append(xs_[0]); his.append(xs_[run_end] if run_end < len(xs_) else xs_[-1])
    lo, hi = int(np.median(los)), int(np.median(his))
    g.update(size=[w, h], body_cx=(lo+hi)//2, body_bottom=int(y1), body_w=hi-lo)
    return g


if __name__ == '__main__':
    meta = {r: split(r) for r in RIG}
    json.dump(meta, open(f'{D}/archer-rig.json', 'w'), indent=1)
    for r, m in meta.items(): print(r, m)
