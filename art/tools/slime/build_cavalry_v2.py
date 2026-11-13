"""기병 v2 애니메이션: 대기 4(6fps) · 공격 6(12fps).
말 탄 등급(정병~장수): 편곤을 쥔 손을 축으로 뒤로 젖혔다가 머리 위로 크게 앞으로 내려침, 말+몸은 내려칠 때 앞으로 살짝 기울어짐.
군졸(말 없음): 두 손 가운데를 축으로 젖혔다 내려침, 손이 벗어나면 젤리 팔로 이어짐.
python3 art/tools/slime/build_cavalry_v2.py → art/out/slime-v2/cavalry-rN.{png,json}"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, 'art/tools/slime')
D = 'art/source/gemini/slime-v2'; O = 'art/out/slime-v2'; P = 'art/preview/slime-v2'
RIG = json.load(open(f'{D}/cavalry-rig.json'))
WIDTH = {1: 90, 2: 150, 3: 150, 4: 150}          # @2x: 군졸은 몸 폭, 말 탄 등급은 말+몸 전체 폭
PAD = 150
# (자루 회전[도, +는 반시계=뒤로 젖힘], 몸 sx, sy, 몸 기울기[도, -는 앞으로], 사슬+몽둥이 회전[도, 화면 기준 절대값, +는 반시계])
IDLE = [(0, 1, 1, 0, 0), (0, 1.015, .985, 0, 0), (0, 1, 1, 0, 0), (0, .99, 1.01, 0, 0)]
ATK_RIDER = [(0, 1, 1, 0, 0), (20, 1.02, .98, 1.5, -8), (-35, 1, 1, -1, 30), (-70, .98, 1.02, -3.5, 105), (-60, .99, 1.01, -2.5, 75), (-25, 1, 1, -.5, 25)]
ATK_FOOT = [(0, 1, 1, 0, 0), (18, 1.04, .96, 0, -10), (-15, 1, 1, 0, 25), (-42, .96, 1.04, 0, 70), (-34, .97, 1.03, 0, 50), (-10, 1, 1, 0, 15)]
HIT = 3


def rot_pt(p, c, deg):
    a = np.radians(-deg)   # 화면 좌표(y 아래)에서 반시계 = +
    x, y = p[0]-c[0], p[1]-c[1]
    return (c[0] + x*np.cos(a) - y*np.sin(a), c[1] + x*np.sin(a) + y*np.cos(a))


def arms(pairs, k, W, H, col, rad, ss=4):
    img = Image.new('RGBA', (W*ss, H*ss)); d = ImageDraw.Draw(img)
    out = (96, 54, 22, 255); lw = 1.6*k*ss*4
    rb, rt = rad*k*.8*ss, rad*k*.72*ss
    def cap(p, q, r0, r1, fill):
        p, q = np.array(p)*ss, np.array(q)*ss; v = q - p; L = np.hypot(*v) or 1; n = np.array([-v[1], v[0]])/L
        d.polygon([tuple(p+n*r0), tuple(q+n*r1), tuple(q-n*r1), tuple(p-n*r0)], fill=fill)
        d.ellipse([q[0]-r1, q[1]-r1, q[0]+r1, q[1]+r1], fill=fill)
    for p, q in pairs: cap(p, q, rb+lw, rt+lw, out)
    for p, q in pairs: cap(p, q, rb, rt, col)
    a = np.asarray(img).copy(); yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    for p, q in pairs:
        a[..., 3][np.hypot(xx-p[0]*ss, yy-p[1]*ss) <= rad*k*ss*1.02] = 0
    return Image.fromarray(a, 'RGBA').resize((W, H), Image.LANCZOS)


def frames(r):
    m = RIG[str(r)]
    body = Image.open(f'{D}/cavalry-r{r}-body.png'); wpn = Image.open(f'{D}/cavalry-r{r}-weapon.png'); fl = Image.open(f'{D}/cavalry-r{r}-flail.png')
    k = WIDTH[r] / m['body_w']
    cx, by = m['body_cx'], m['body_bottom']
    rider = r > 1
    piv = tuple(m['hands'][0][0]) if rider else tuple(m['pivot'])
    bw, bh = round(body.width*k), round(body.height*k)
    W, H = bw + 2*PAD, bh + PAD
    ax, ay = PAD + round(cx*k), H - 10
    wa = np.asarray(wpn); hx, hy = m['hands'][0][0]
    col = tuple(int(v) for v in np.median(wa[hy-6:hy+6, hx+6:hx+20, :3].reshape(-1, 3), 0)) + (255,)
    tip0 = m['handle'][1]
    def F(p):  # 원본 → 프레임
        return (ax + (p[0]-cx)*k, ay - (by-p[1])*k)
    def draw(ang, sx, sy, tilt, srot):
        c = Image.new('RGBA', (W, H))
        b = body.resize((round(body.width*k*sx), round(body.height*k*sy)), Image.LANCZOS)
        c.alpha_composite(b, (ax - round(cx*k*sx), ay - round(by*k*sy)))
        # 무기: 축(pv)을 중심으로 회전한 큰 캔버스를 만들어 붙임
        pv = F(piv); pv = (pv[0], ay - (ay - pv[1])*sy)
        wl = wpn.resize((round(wpn.width*k), round(wpn.height*k)), Image.LANCZOS)
        layer = Image.new('RGBA', (W, H)); layer.alpha_composite(wl, (ax - round(cx*k), ay - round(by*k) - round((sy-1)*(by-piv[1])*k)))
        layer = layer.rotate(ang, center=pv, resample=Image.BICUBIC)
        # 사슬+몽둥이: 자루 끝(고리)에 매달려 따로 흔들림
        fll = fl.resize((round(fl.width*k), round(fl.height*k)), Image.LANCZOS)
        fla = Image.new('RGBA', (W, H)); off_y = -round((sy-1)*(by-piv[1])*k)
        fla.alpha_composite(fll, (ax - round(cx*k), ay - round(by*k) + off_y))
        at = F(tip0); at = (at[0], at[1] + off_y)
        fla = fla.rotate(srot, center=at, resample=Image.BICUBIC)
        nat = rot_pt(at, pv, ang)
        fla = fla.transform((W, H), Image.AFFINE, (1, 0, at[0]-nat[0], 0, 1, at[1]-nat[1]), resample=Image.BICUBIC)
        if not rider and abs(ang) > 2:      # 군졸: 손이 원래 자리에서 벗어나면 젤리 팔
            pairs = [(F(h), F(rot_pt(h, piv, ang))) for h, _ in m['hands']]
            c.alpha_composite(arms(pairs, k, W, H, col, m['hands'][0][1]))
        c.alpha_composite(fla)
        c.alpha_composite(layer)
        if tilt:   # 말 탄 등급: 뒷발 쪽을 축으로 앞뒤 기울기
            c = c.rotate(-tilt * -1, center=(ax - bw*.25, ay), resample=Image.BICUBIC)
        # 타격점 = 몽둥이 끝(사슬 고리에서 아래로 매달린 길이만큼, 회전 반영)
        L = 230*k; a_ = np.radians(-90 + srot)
        tip = (nat[0] + L*np.cos(a_), nat[1] - L*np.sin(a_))
        return c, tip
    idle = [draw(*f)[0] for f in IDLE]
    atk = [draw(*f) for f in (ATK_RIDER if rider else ATK_FOOT)]
    return idle, [a[0] for a in atk], atk[HIT][1], (ax, ay), (W, H)


def trim_all(frs):
    bb = None
    for f in frs:
        b = f.getbbox()
        bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    return bb


def sheet(r):
    idle, atk, hit, (ax, ay), (W, H) = frames(r)
    allf = idle + atk
    x0, y0, x1, y1 = trim_all(allf); x0 -= 4; y0 -= 4; x1 += 4; y1 = H
    idle = [f.crop((x0, y0, x1, y1)) for f in idle]; atk = [f.crop((x0, y0, x1, y1)) for f in atk]
    ax, ay, hit = ax - x0, ay - y0, (hit[0] - x0, hit[1] - y0)
    W, H = x1 - x0, y1 - y0
    names = [('idle', i) for i in range(4)] + [('attack', i) for i in range(6)]
    sh = Image.new('RGBA', (W*10, H)); fr = {}
    for n, ((nm, i), f) in enumerate(zip(names, idle + atk)):
        sh.alpha_composite(f, (n*W, 0)); fr[f'cavalry-r{r}-{nm}-{i}'] = {'frame': {'x': n*W, 'y': 0, 'w': W, 'h': H}}
    sh.save(f'{O}/cavalry-r{r}.png')
    json.dump({'frames': fr, 'meta': {'image': f'cavalry-r{r}.png', 'scale': 2, 'size': {'w': sh.width, 'h': H},
               'anchor': {'x': round(ax/W, 4), 'y': round(ay/H, 4)},
               'anims': {'idle': {'frames': 4, 'fps': 6, 'loop': True}, 'attack': {'frames': 6, 'fps': 12, 'loop': False}},
               'events': {'hit': {'frame': HIT, 'x': round(hit[0]), 'y': round(hit[1])}}}}, open(f'{O}/cavalry-r{r}.json', 'w'), indent=1)
    return idle, atk


def gif(res):
    W = sum(res[r][0][0].width + 20 for r in res); H = max(res[r][0][0].height for r in res) + 20
    seq = [('i', i) for i in [0, 1, 2, 3, 0, 1]] + [('a', i) for i in range(6)] + [('i', 0)]*3
    out = []
    for nm, i in seq:
        c = Image.new('RGBA', (W, H), (250, 246, 236, 255)); x = 10
        for r in sorted(res):
            f = res[r][0][i] if nm == 'i' else res[r][1][i]
            c.alpha_composite(f, (x, H - 10 - f.height)); x += res[r][0][0].width + 20
        out.append(c.convert('RGB'))
    out[0].save(f'{P}/cavalry-anim.gif', save_all=True, append_images=out[1:], duration=[166 if n == 'i' else 83 for n, _ in seq], loop=0)


if __name__ == '__main__':
    res = {r: sheet(r) for r in (1, 2, 3, 4)}
    gif(res); print('ok')
