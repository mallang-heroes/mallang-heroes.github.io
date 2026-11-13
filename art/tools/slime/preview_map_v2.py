"""새 슬라임 유닛을 봄 맵 칸 위에 올려 보기(몸 가운데 = 칸 가운데). python3 art/tools/slime/preview_map_v2.py"""
import json
from PIL import Image
O = 'art/out/slime-v2'
m = Image.open('art/source/gemini/map-seasons/season-01-spring-garden.png').convert('RGBA')
k = 718/585/2 * 58/(63*718/585)
PADS = {('spear', 1): [(195, 712)], ('archer', 1): [(277, 712)], ('gunner', 1): [(360, 712)],
        ('archer', 2): [(195, 478)], ('gunner', 2): [(277, 478)], ('spear', 2): [(360, 478)],
        ('spear', 3): [(195, 560)], ('archer', 3): [(277, 560)], ('gunner', 3): [(360, 560)],
        ('spear', 4): [(525, 478)], ('archer', 4): [(277, 325)], ('gunner', 4): [(360, 325)],
        ('cavalry', 1): [(442, 712)], ('cavalry', 2): [(442, 478)], ('cavalry', 3): [(442, 560)], ('cavalry', 4): [(442, 325)]}
for (u, r), pts in PADS.items():
    j = json.load(open(f'{O}/{u}-r{r}.json')); sh = Image.open(f'{O}/{u}-r{r}.png')
    f = j['frames'][f'{u}-r{r}-idle-0']['frame']; im = sh.crop((f['x'], f['y'], f['x']+f['w'], f['y']+f['h']))
    ax, ay = j['meta']['anchor']['x']*f['w'], j['meta']['anchor']['y']*f['h']
    s = im.resize((round(im.width*k), round(im.height*k)), Image.LANCZOS)
    for cx, cy in pts:
        m.alpha_composite(s, (round(cx - ax*k), round(cy + 16 - ay*k)))
m.save('art/preview/slime-v2/units-on-spring-map.png')
