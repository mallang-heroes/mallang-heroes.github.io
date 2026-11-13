"""새 슬라임(v2) 창병 4종 자르기 + 미리보기. python3 art/tools/slime/cut_v2.py"""
import sys
sys.path.insert(0, 'art/tools/slime')
from PIL import Image
from keying import key_out, components
D = 'art/source/gemini/slime-v2'
P = 'art/preview/slime-v2'
cuts = {}
for r in (1, 2, 3, 4):
    img = key_out(f'{D}/spear-r{r}-src.png')
    comps = sorted(components(img), key=lambda c: -c[2])
    im = comps[0][1]
    im.save(f'{D}/spear-r{r}-cut.png')
    cuts[r] = im
    print(r, im.size)
# 크기: r2~r4는 같은 배율로 그려짐, r1은 창 길이(가로 폭)로 r4에 맞춤
base = cuts[4].width
rel = {1: .72, 2: .82, 3: .91, 4: 1.0}
norm = {}
for r, im in cuts.items():
    k = (base / im.width if r == 1 else 1.0) * rel[r]
    norm[r] = im.resize((round(im.width*k), round(im.height*k)), Image.LANCZOS)
H = max(i.height for i in norm.values()) + 40
W = sum(i.width for i in norm.values()) + 50*5
sheet = Image.new('RGBA', (W, H), (250, 246, 236, 255))
x = 50
for r in (1, 2, 3, 4):
    im = norm[r]; sheet.alpha_composite(im, (x, H - 20 - im.height)); x += im.width + 50
sheet.save(f'{P}/spear-lineup.png')
# 봄 맵 위: 칸(약 58px) 기준 장수 몸 폭이 칸에 맞게
m = Image.open('art/source/gemini/map-seasons/season-01-spring-garden.png').convert('RGBA')
k = 92 / base   # 장수 전체(창 포함) 폭 92px
spots = {1: [(195, 712), (277, 712), (360, 712)], 2: [(195, 478), (277, 478)], 3: [(360, 560), (442, 560)], 4: [(525, 478), (277, 325)]}
for r, pts in spots.items():
    im = norm[r]; s = im.resize((max(1, round(im.width*k)), max(1, round(im.height*k))), Image.LANCZOS)
    for cx, cy in pts:
        m.alpha_composite(s, (cx - s.width//2 + 4, cy + 18 - s.height))
m.save(f'{P}/spear-on-spring-map.png')
