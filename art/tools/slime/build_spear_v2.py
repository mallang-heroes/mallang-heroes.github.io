"""창병 v2 애니메이션: 대기 4(6fps) · 공격 6(12fps). 몸 + (두 손+창) 2겹 리깅.
python3 art/tools/slime/build_spear_v2.py → art/out/slime-v2/spear-rN.{png,json}, 미리보기 GIF·맵"""
import json, os
import numpy as np
from PIL import Image
D = 'art/source/gemini/slime-v2'; O = 'art/out/slime-v2'; P = 'art/preview/slime-v2'
os.makedirs(O, exist_ok=True)
RIG = json.load(open(f'{D}/spear-rig.json'))
BODY_W = {1: 90, 2: 102, 3: 113, 4: 124}       # @2x 몸 폭(창 제외). 장수 ≈ 칸 63pt 보드 기준
PAD_L, PAD_R, PAD_T, PAD_B = 70, 150, 20, 12    # 찌르기 여유
# (창대 방향 이동[원본px], 몸 sx, sy, 몸 x이동[원본px])
IDLE = [(0, 1, 1, 0), (0, 1.025, .975, 0), (0, 1, 1, 0), (0, .98, 1.02, 0)]
ATK = [(0, 1, 1, 0), (-45, 1.06, .94, -14), (-60, 1.08, .92, -18), (150, .95, 1.05, 22), (125, .97, 1.03, 16), (35, 1, 1, 4)]


def frames(r):
    m = RIG[str(r)]
    body = Image.open(f'{D}/spear-r{r}-body.png'); wpn = Image.open(f'{D}/spear-r{r}-weapon.png')
    bb = np.asarray(body)[..., 3] > 128
    cols = bb.sum(0); xs = np.where(cols > cols.max()*.35)[0]
    bw = xs[-1] - xs[0]
    k = BODY_W[r] / bw
    cx, by = m['body_cx'], m['body_bottom']
    (bx0, by0), (tx, ty) = m['butt'], m['tip']
    L = np.hypot(tx-bx0, ty-by0); ux, uy = (tx-bx0)/L, (ty-by0)/L
    hand_h = by - np.mean([h[1] for h in m['hands']])
    W = round(body.width*k) + PAD_L + PAD_R; H = round(body.height*k) + PAD_T + PAD_B + 20
    ax, ay = PAD_L + round(cx*k), H - PAD_B     # 앵커 = 몸 발밑 가운데
    def draw(d, sx, sy, mx):
        c = Image.new('RGBA', (W, H))
        bw_, bh_ = round(body.width*k*sx), round(body.height*k*sy)
        b = body.resize((bw_, bh_), Image.LANCZOS)
        bx = ax + round(mx*k) - round(cx*k*sx); byy = ay - round(by*k*sy)
        c.alpha_composite(b, (bx, byy))
        w = wpn.resize((round(wpn.width*k), round(wpn.height*k)), Image.LANCZOS)
        wx = ax - round(cx*k) + round((d*ux + mx)*k); wy = ay - round(by*k) + round(d*uy*k) - round((sy-1)*hand_h*k)
        c.alpha_composite(w, (wx, wy))
        tip = (wx + round(tx*k), wy + round(ty*k))
        return c, tip
    idle = [draw(*f)[0] for f in IDLE]
    atk = [draw(*f) for f in ATK]
    return idle, [a[0] for a in atk], atk[3][1], (ax, ay), (W, H)


def sheet(r):
    idle, atk, hit, (ax, ay), (W, H) = frames(r)
    allf = [('idle', i, f) for i, f in enumerate(idle)] + [('attack', i, f) for i, f in enumerate(atk)]
    sh = Image.new('RGBA', (W*len(allf), H))
    fr = {}
    for n, (name, i, f) in enumerate(allf):
        sh.alpha_composite(f, (n*W, 0))
        fr[f'spear-r{r}-{name}-{i}'] = {'frame': {'x': n*W, 'y': 0, 'w': W, 'h': H}}
    sh.save(f'{O}/spear-r{r}.png')
    json.dump({'frames': fr, 'meta': {'image': f'spear-r{r}.png', 'scale': 2, 'size': {'w': sh.width, 'h': H},
               'anchor': {'x': round(ax/W, 4), 'y': round(ay/H, 4)},
               'anims': {'idle': {'frames': 4, 'fps': 6, 'loop': True}, 'attack': {'frames': 6, 'fps': 12, 'loop': False}},
               'events': {'hit': {'frame': 3, 'x': hit[0], 'y': hit[1]}}}}, open(f'{O}/spear-r{r}.json', 'w'), indent=1)
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
    out[0].save(f'{P}/spear-anim.gif', save_all=True, append_images=out[1:], duration=dur, loop=0)


def on_map(res):
    m = Image.open('art/source/gemini/map-seasons/season-01-spring-garden.png').convert('RGBA')
    k = 718/585/2 * 58/(63*718/585)   # 시안 칸(약 58px)을 게임 칸(63)으로 보고 맞춤
    pads = {1: [(195, 712), (277, 712), (360, 712)], 2: [(195, 478), (277, 478)], 3: [(360, 560), (442, 560)], 4: [(525, 478), (277, 325)]}
    for r, pts in pads.items():
        f = res[r][0][0]; ax, ay = res[r][2]
        s = f.resize((round(f.width*k), round(f.height*k)), Image.LANCZOS)
        for cx, cy in pts:   # 몸 가운데를 칸 가운데에, 발은 칸 가운데보다 조금 아래
            m.alpha_composite(s, (cx - round(ax*k), cy + 16 - round(ay*k)))
    m.save(f'{P}/spear-on-spring-map.png')


if __name__ == '__main__':
    res = {r: sheet(r) for r in (1, 2, 3, 4)}
    gif(res); on_map(res)
    print('ok')
