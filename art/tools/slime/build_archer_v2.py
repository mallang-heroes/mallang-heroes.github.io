"""궁병 v2 애니메이션: 대기 4(6fps) · 공격 6(12fps).
겹: 몸(활·앞팔 포함) → 시위(코드로 그림) → 뒷손 → 화살. 쏘는 프레임에서 화살은 투사체로 빠짐.
python3 art/tools/slime/build_archer_v2.py → art/out/slime-v2/archer-rN.{png,json}, archer-arrow.png"""
import json, os
import numpy as np
from PIL import Image, ImageDraw
D = 'art/source/gemini/slime-v2'; O = 'art/out/slime-v2'; P = 'art/preview/slime-v2'
os.makedirs(O, exist_ok=True)
RIG = json.load(open(f'{D}/archer-rig.json'))
BODY_W = {1: 90, 2: 102, 3: 113, 4: 124}
PAD_L, PAD_R, PAD_T, PAD_B = 30, 40, 16, 12
# (당김[원본px], 몸 sx, sy, 화살 보임, 시위 떨림[원본px])
IDLE = [(0, 1, 1, 1, 0), (0, 1.025, .975, 1, 0), (0, 1, 1, 1, 0), (0, .98, 1.02, 1, 0)]
ATK = [(0, 1, 1, 1, 0), (35, 1.02, .98, 1, 0), (70, 1.05, .95, 1, 0), (0, .97, 1.03, 0, 14), (0, 1, 1, 0, -6), (0, 1, 1, 1, 0)]
SHOT = 3


def frames(r):
    m = RIG[str(r)]
    body = Image.open(f'{D}/archer-r{r}-body.png'); arrow = Image.open(f'{D}/archer-r{r}-arrow.png'); hand = Image.open(f'{D}/archer-r{r}-hand.png')
    k = BODY_W[r] / m['body_w']
    cx, by = m['body_cx'], m['body_bottom']
    nx, ny = m['nock']; tx, ty = m['tip']
    L = np.hypot(tx-nx, ty-ny); ux, uy = (tx-nx)/L, (ty-ny)/L
    hh = by - ny                     # 손 높이(발밑 기준)
    W = round(body.width*k) + PAD_L + PAD_R; H = round(body.height*k) + PAD_T + PAD_B
    ax, ay = PAD_L + round(cx*k), H - PAD_B
    sc = lambda im: im.resize((max(1, round(im.width*k)), max(1, round(im.height*k))), Image.LANCZOS)
    B_, A_, H_ = sc(body), sc(arrow), sc(hand)
    def P(x, y, sy=1.0):   # 원본 좌표 → 프레임 좌표 (몸 세로 눌림 반영)
        return ax + (x - cx)*k, ay - (by - y)*k*sy
    def draw(pull, sx, sy, show, wob):
        c = Image.new('RGBA', (W, H))
        b = body.resize((round(body.width*k*sx), round(body.height*k*sy)), Image.LANCZOS)
        c.alpha_composite(b, (ax - round(cx*k*sx), ay - round(by*k*sy)))
        dy = -(sy - 1)*hh*k
        # 활 끝(몸 변형 따라감)
        def bp(p): x, y = P(*p); return ax + (p[0]-cx)*k*sx, ay - (by-p[1])*k*sy
        top, bot = bp(m['top']), bp(m['bot'])
        nock = (P(nx, ny)[0] - pull*ux*k, P(nx, ny)[1] + dy - pull*uy*k)
        # 시위
        ss = 4; s = Image.new('RGBA', (W*ss, H*ss)); d = ImageDraw.Draw(s)
        if show or pull:
            mid = nock
        else:   # 쏜 직후: 시위가 곧게 펴지며 떨림
            mx_, my_ = (top[0]+bot[0])/2, (top[1]+bot[1])/2
            mid = (mx_ + wob*k, my_)
        pts = [(top[0]*ss, top[1]*ss), (mid[0]*ss, mid[1]*ss), (bot[0]*ss, bot[1]*ss)]
        d.line(pts, fill=(110, 84, 52, 255), width=round(3.4*k*ss*1.6 + ss), joint='curve')
        d.line(pts, fill=(238, 226, 188, 255), width=round(2.2*k*ss*1.6), joint='curve')
        c.alpha_composite(s.resize((W, H), Image.LANCZOS))
        # 뒷손·화살 (당김만큼 화살 축 뒤로)
        off = (round(-pull*ux*k), round(dy - pull*uy*k))
        base = (ax - round(cx*k), ay - round(by*k))
        c.alpha_composite(H_, (base[0] + off[0], base[1] + off[1]))
        if show:
            c.alpha_composite(A_, (base[0] + off[0], base[1] + off[1]))
        return c, P(tx, ty), P(nx, ny)
    idle = [draw(*f)[0] for f in IDLE]
    atk = [draw(*f) for f in ATK]
    tip, nock = atk[SHOT - 1][1], atk[SHOT - 1][2]
    ang = float(np.degrees(np.arctan2(-(ty-ny), tx-nx)))
    return idle, [a[0] for a in atk], (ax, ay), (W, H), dict(tip=tip, nock=nock, angle=ang), A_, base_of(A_, ax, ay, cx, by, k)


def base_of(A, ax, ay, cx, by, k):
    return (ax - round(cx*k), ay - round(by*k))


def sheet(r):
    idle, atk, (ax, ay), (W, H), shot, A_, base = frames(r)
    allf = [('idle', i, f) for i, f in enumerate(idle)] + [('attack', i, f) for i, f in enumerate(atk)]
    sh = Image.new('RGBA', (W*len(allf), H)); fr = {}
    for n, (name, i, f) in enumerate(allf):
        sh.alpha_composite(f, (n*W, 0)); fr[f'archer-r{r}-{name}-{i}'] = {'frame': {'x': n*W, 'y': 0, 'w': W, 'h': H}}
    sh.save(f'{O}/archer-r{r}.png')
    if r == 4:   # 투사체 화살(장수 크기 기준 한 장, 수평 오른쪽)
        bb = A_.getbbox(); a = A_.crop(bb).rotate(-shot['angle'], expand=True, resample=Image.BICUBIC)   # 수평(오른쪽)으로 펴서 저장
        a.crop(a.getbbox()).save(f'{O}/archer-arrow.png')
    json.dump({'frames': fr, 'meta': {'image': f'archer-r{r}.png', 'scale': 2, 'size': {'w': sh.width, 'h': H},
               'anchor': {'x': round(ax/W, 4), 'y': round(ay/H, 4)},
               'anims': {'idle': {'frames': 4, 'fps': 6, 'loop': True}, 'attack': {'frames': 6, 'fps': 12, 'loop': False}},
               'events': {'projectile': {'frame': SHOT, 'x': round(shot['tip'][0]), 'y': round(shot['tip'][1]),
                                         'angle': round(shot['angle'], 1), 'sprite': 'archer-arrow.png'}}}},
              open(f'{O}/archer-r{r}.json', 'w'), indent=1)
    return idle, atk, (ax, ay), shot


def gif(res):
    W = sum(res[r][0][0].width + 20 for r in res) + 140; H = max(res[r][0][0].height for r in res) + 20
    seq = [('idle', i) for i in [0, 1, 2, 3, 0, 1]] + [('attack', i) for i in range(6)] + [('idle', 0)]*3
    arrow = Image.open(f'{O}/archer-arrow.png')
    out, dur = [], []
    for si, (name, i) in enumerate(seq):
        c = Image.new('RGBA', (W, H), (250, 246, 236, 255)); x = 10
        for r in sorted(res):
            idle, atk, (ax, ay), shot = res[r]
            f = idle[i] if name == 'idle' else atk[i]
            y0 = H - 10 - f.height
            c.alpha_composite(f, (x, y0))
            if name == 'attack' and i >= 3:      # 날아가는 화살 미리보기
                kk = (BODY_W[r]/124)
                a = arrow.resize((round(arrow.width*kk), round(arrow.height*kk)), Image.LANCZOS).rotate(shot['angle'], expand=True, resample=Image.BICUBIC)
                dist = (i - 2) * 45
                ang = np.radians(shot['angle'])
                px = x + shot['tip'][0] + dist*np.cos(ang) - a.width; py = y0 + shot['tip'][1] - dist*np.sin(ang) - a.height*.15
                c.alpha_composite(a, (round(px), round(py)))
            x += idle[0].width + 20
        out.append(c.convert('RGB')); dur.append(166 if name == 'idle' else 83)
    out[0].save(f'{P}/archer-anim.gif', save_all=True, append_images=out[1:], duration=dur, loop=0)


if __name__ == '__main__':
    res = {r: sheet(r) for r in (1, 2, 3, 4)}
    gif(res); print('ok')
