"""포수 v2 애니메이션 (창병 리깅 기반: 쏘면 총통이 자루 방향 뒤로 튕기고 몸이 눌림, 총구 불꽃·연기는 코드로): 대기 4(6fps) · 공격 6(12fps). 몸 + (두 손+창) 2겹 리깅.
python3 art/tools/slime/build_spear_v2.py → art/out/slime-v2/spear-rN.{png,json}, 미리보기 GIF·맵"""
import json, os
import numpy as np
from PIL import Image, ImageDraw
D = 'art/source/gemini/slime-v2'; O = 'art/out/slime-v2'; P = 'art/preview/slime-v2'
os.makedirs(O, exist_ok=True)
RIG = json.load(open(f'{D}/gunner-rig.json'))
BODY_W = {1: 90, 2: 102, 3: 113, 4: 124}       # @2x 몸 폭(창 제외). 장수 ≈ 칸 63pt 보드 기준
PAD_L, PAD_R, PAD_T, PAD_B = 70, 190, 30, 12    # 찌르기 여유
# (창대 방향 이동[원본px], 몸 sx, sy, 몸 x이동[원본px])
IDLE = [(0, 1, 1, 0), (0, 1.025, .975, 0), (0, 1, 1, 0), (0, .98, 1.02, 0)]
ATK = [(0, 1, 1, 0), (6, .98, 1.02, 2), (-55, 1.08, .92, -16), (-40, 1.05, .95, -12), (-15, 1.02, .98, -5), (0, 1, 1, 0)]
FIRE = 2
FX = {2: 'flash', 3: 'smoke1', 4: 'smoke2'}


HAND_R = 40   # 원본 px


def arms(m, k, anchor, body_ref, body_tf, off, W, H, col, ss=4):
    ax, ay = anchor; cx, by = body_ref; sx, sy, mx = body_tf
    img = Image.new('RGBA', (W*ss, H*ss)); d = ImageDraw.Draw(img)
    out = (88, 26, 30, 255)
    segs = []
    for hx, hy in m['hands']:
        # 몸 쪽 뿌리: 몸 변형을 따라감, 손 쪽: 무기 이동만큼
        bx_ = ax + (mx + (hx - cx)*sx)*k; by_ = ay - (by - hy)*sy*k
        tx_ = ax + (hx - cx)*k + off[0]; ty_ = ay - (by - hy)*k + off[1]
        segs.append(((bx_*ss, by_*ss), (tx_*ss, ty_*ss)))
    rb, rt = HAND_R*k*.85*ss, HAND_R*k*.78*ss
    def capsule(p, q, r0, r1, fill):
        p, q = np.array(p), np.array(q); v = q - p; L = np.hypot(*v) or 1; n = np.array([-v[1], v[0]])/L
        d.polygon([tuple(p + n*r0), tuple(q + n*r1), tuple(q - n*r1), tuple(p - n*r0)], fill=fill)
        d.ellipse([q[0]-r1, q[1]-r1, q[0]+r1, q[1]+r1], fill=fill)
    lw = 1.6*k*ss*4
    for p, q in segs: capsule(p, q, rb + lw, rt + lw, out)
    for p, q in segs:
        capsule(p, q, rb, rt, col + (255,))
    # 손이 원래 있던 자리(몸 위)는 비워 둠 → 그 아래 몸·띠가 그대로 보이고, 팔은 그 둘레에서 뻗어 나옴
    a = np.asarray(img).copy(); yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    for p, q in segs:
        a[..., 3][np.hypot(xx - p[0], yy - p[1]) <= HAND_R*k*ss*1.02] = 0
    return Image.fromarray(a, 'RGBA').resize((W, H), Image.LANCZOS)


def frames(r):
    m = RIG[str(r)]
    body = Image.open(f'{D}/gunner-r{r}-body.png'); wpn = Image.open(f'{D}/gunner-r{r}-weapon.png')
    bb = np.asarray(body)[..., 3] > 128
    cols = bb.sum(0); xs = np.where(cols > cols.max()*.35)[0]
    bw = xs[-1] - xs[0]
    k = BODY_W[r] / bw
    cx, by = m['body_cx'], m['body_bottom']
    (bx0, by0), (tx, ty) = m['butt'], m['tip']
    L = np.hypot(tx-bx0, ty-by0); ux, uy = (tx-bx0)/L, (ty-by0)/L
    hand_h = by - np.mean([h[1] for h in m['hands']])
    wa = np.asarray(wpn); hx0, hy0 = m['hands'][0]
    hand_col = tuple(int(v) for v in np.median(wa[hy0-8:hy0+8, hx0+10:hx0+26, :3].reshape(-1, 3), 0))
    W = round(body.width*k) + PAD_L + PAD_R; H = round(body.height*k) + PAD_T + PAD_B + 20
    ax, ay = PAD_L + round(cx*k), H - PAD_B     # 앵커 = 몸 발밑 가운데
    def draw(d, sx, sy, mx):
        c = Image.new('RGBA', (W, H))
        bw_, bh_ = round(body.width*k*sx), round(body.height*k*sy)
        b = body.resize((bw_, bh_), Image.LANCZOS)
        bx = ax + round(mx*k) - round(cx*k*sx); byy = ay - round(by*k*sy)
        c.alpha_composite(b, (bx, byy))
        # 손이 몸에서 떨어지면 젤리 팔이 늘어나 이어지게 (몸 → 팔 → 손·창 순서)
        dx, dy = (d*ux + mx)*k, d*uy*k - (sy-1)*hand_h*k
        if abs(d) > 3:
            c.alpha_composite(arms(m, k, (ax, ay), (cx, by), (sx, sy, mx), (dx, dy), W, H, hand_col))
        w = wpn.resize((round(wpn.width*k), round(wpn.height*k)), Image.LANCZOS)
        wx = ax - round(cx*k) + round((d*ux + mx)*k); wy = ay - round(by*k) + round(d*uy*k) - round((sy-1)*hand_h*k)
        c.alpha_composite(w, (wx, wy))
        tip = (wx + round(tx*k), wy + round(ty*k))
        return c, tip, (ux, uy)
    idle = [draw(*f)[0] for f in IDLE]
    atk = []
    for i, f in enumerate(ATK):
        c, tip, u = draw(*f)
        if i in FX:
            fx(c, tip, u, FX[i], k)
        atk.append((c, tip))
    return idle, [a[0] for a in atk], atk[FIRE][1], (ax, ay), (W, H)


def fx(c, tip, u, kind, k, ss=4):
    W, H = c.size
    s = Image.new('RGBA', (W*ss, H*ss)); d = ImageDraw.Draw(s)
    ux, uy = u; nx, ny = -uy, ux
    R = 140*k*ss
    cx0, cy0 = tip[0]*ss + ux*R*.55, tip[1]*ss + uy*R*.55
    if kind == 'flash':
        def star(r_out, r_in, n, col):
            pts = []
            for j in range(n*2):
                ang = np.pi*j/n; rr = r_out if j % 2 == 0 else r_in
                # 총구 방향으로 길게
                ex, ey = np.cos(ang), np.sin(ang)
                fx_, fy_ = ex*1.5, ey*.85
                pts.append((cx0 + (fx_*ux + fy_*nx)*rr, cy0 + (fx_*uy + fy_*ny)*rr))
            d.polygon(pts, fill=col)
        star(R, R*.45, 8, (232, 96, 36, 255)); star(R*.72, R*.34, 8, (255, 196, 64, 255)); star(R*.38, R*.2, 6, (255, 250, 220, 255))
    else:
        n = 3 if kind == 'smoke1' else 4
        a_ = 200 if kind == 'smoke1' else 120
        grow = 1.0 if kind == 'smoke1' else 1.35
        for j in range(n):
            t = (j + .6) * R * .55 * grow
            rr = R*(.32 + .1*j)*grow
            px, py = cx0 + ux*t + nx*R*.15*((-1)**j), cy0 + uy*t + ny*R*.15*((-1)**j) - j*R*.12
            d.ellipse([px-rr, py-rr, px+rr, py+rr], fill=(222, 216, 206, a_), outline=(150, 140, 130, a_), width=max(1, round(1.5*ss)))
    c.alpha_composite(s.resize((W, H), Image.LANCZOS))


def sheet(r):
    idle, atk, hit, (ax, ay), (W, H) = frames(r)
    allf = [('idle', i, f) for i, f in enumerate(idle)] + [('attack', i, f) for i, f in enumerate(atk)]
    sh = Image.new('RGBA', (W*len(allf), H))
    fr = {}
    for n, (name, i, f) in enumerate(allf):
        sh.alpha_composite(f, (n*W, 0))
        fr[f'gunner-r{r}-{name}-{i}'] = {'frame': {'x': n*W, 'y': 0, 'w': W, 'h': H}}
    sh.save(f'{O}/gunner-r{r}.png')
    json.dump({'frames': fr, 'meta': {'image': f'gunner-r{r}.png', 'scale': 2, 'size': {'w': sh.width, 'h': H},
               'anchor': {'x': round(ax/W, 4), 'y': round(ay/H, 4)},
               'anims': {'idle': {'frames': 4, 'fps': 6, 'loop': True}, 'attack': {'frames': 6, 'fps': 12, 'loop': False}},
               'events': {'projectile': {'frame': FIRE, 'x': hit[0], 'y': hit[1]}}}}, open(f'{O}/gunner-r{r}.json', 'w'), indent=1)
    return idle, atk, (ax, ay)


def gif(res):
    W = sum(max(f.width for f in res[r][0]) + 20 for r in res); H = max(res[r][0][0].height for r in res) + 20
    seq = [('idle', i) for i in [0, 1, 2, 3, 0, 1, 2, 3]] + [('attack', i) for i in range(6)] + [('idle', 0)]*3
    out = []
    for name, i in seq:
        c = Image.new('RGBA', (W, H), (250, 246, 236, 255)); x = 10
        for r in sorted(res):
            f = res[r][0][i] if name == 'idle' else res[r][1][i]
            c.alpha_composite(f, (x, H - 10 - f.height)); x += res[r][0][0].width + 20
        out.append(c.convert('RGB'))
    dur = [166 if n == 'idle' else 83 for n, _ in seq]
    out[0].save(f'{P}/gunner-anim.gif', save_all=True, append_images=out[1:], duration=dur, loop=0)


def on_map(res):
    m = Image.open('art/source/gemini/map-seasons/season-01-spring-garden.png').convert('RGBA')
    k = 718/585/2 * 58/(63*718/585)   # 시안 칸(약 58px)을 게임 칸(63)으로 보고 맞춤
    pads = {1: [(195, 712), (277, 712), (360, 712)], 2: [(195, 478), (277, 478)], 3: [(360, 560), (442, 560)], 4: [(525, 478), (277, 325)]}
    for r, pts in pads.items():
        f = res[r][0][0]; ax, ay = res[r][2]
        s = f.resize((round(f.width*k), round(f.height*k)), Image.LANCZOS)
        for cx, cy in pts:   # 몸 가운데를 칸 가운데에, 발은 칸 가운데보다 조금 아래
            m.alpha_composite(s, (cx - round(ax*k), cy + 16 - round(ay*k)))
    m.save(f'{P}/gunner-on-spring-map.png')


if __name__ == '__main__':
    res = {r: sheet(r) for r in (1, 2, 3, 4)}
    gif(res); on_map(res)
    print('ok')
