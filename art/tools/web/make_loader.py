"""web/index.html 로딩 화면 생성기.

엔진(Flutter)을 받는 동안부터 그림을 다 받을 때까지 보이는 HTML 로딩 화면.
진행 막대 끝을 군졸 슬라임 6병과가 뛰어가고, 그 앞에서 멧돼지·구미호·귀신이 도망간다.
그림은 게임 에셋(assets/images/...)의 걷기 시트를 그대로 쓴다.
실행: python3 art/tools/web/make_loader.py  (저장소 루트에서)
"""
import json, io
from PIL import Image, ImageFilter

ROOT = '.'
IMG = 'assets/images/'
SLIMES = ['spear', 'archer', 'gunner', 'cavalry', 'navy', 'mystic']
MONS = ['mob-boar', 'mob-gumiho', 'mob-ghost']
SLIME_K, MON_K = 0.62, 0.62 * 1.35   # @2x 프레임 → 보드 픽셀 배율
BX, BY, BW, BH = 330, 520, 900, 26

def sprite(path, k):
    d = json.load(open(f'{ROOT}/{IMG}{path}.json'))
    fr = list(d['frames'].values())
    f0 = fr[0]
    w, h = f0['frame']['w'], f0['frame']['h']
    n = len(fr)
    fps = d['meta'].get('fps', 10)
    return dict(url=f'assets/{IMG}{path}.webp', w=round(w * k, 1), h=round(h * k, 1), n=n,
                ax=round(f0['anchor']['x'] * w * k, 1), ay=round(f0['anchor']['y'] * h * k, 1),
                dur=round(n / fps, 3))

# 흐린 맵 배경 (작게 줄여 web/loader-bg.jpg)
bg = Image.open(f'{ROOT}/{IMG}map/map-bg.webp').convert('RGB').resize((520, 240), Image.LANCZOS)
bg = bg.filter(ImageFilter.GaussianBlur(3))
bg = Image.blend(bg, Image.new('RGB', bg.size, (30, 36, 22)), 0.45)
bg.save(f'{ROOT}/web/loader-bg.jpg', quality=78)

css, html = [], []
def spr_css(cls, s):
    css.append(f".{cls}{{width:{s['w']}px;height:{s['h']}px;background:url('{s['url']}') 0 0/{s['w']*s['n']:.1f}px {s['h']}px no-repeat;"
               f"animation:{cls}-a {s['dur']}s steps({s['n']}) infinite}}"
               f"@keyframes {cls}-a{{to{{background-position-x:-{s['w']*s['n']:.1f}px}}}}")

for j, k in enumerate(SLIMES):
    s = sprite(f'units/{k}/gunjol/unit-{k}-gunjol-walk', SLIME_K)
    cls = f's{j}'
    spr_css(cls, s)
    x = -12 - j * 62
    html.append(f'<div class="hop" style="left:{x - s["ax"]:.1f}px;top:{-2 - s["ay"]:.1f}px;animation-delay:-{j*0.13:.2f}s"><div class="{cls}"></div></div>')
for j, k in enumerate(MONS):
    s = sprite(f'monsters/{k}/{k}-walk', MON_K)
    cls = f'm{j}'
    spr_css(cls, s)
    x = 150 + j * 92
    anim = 'float' if k == 'mob-ghost' else 'flee'
    bang = '<b class="bang">!</b>' if j == 0 else ''
    html.append(f'<div class="{anim}" style="left:{x - s["ax"]:.1f}px;top:{-2 - s["ay"]:.1f}px;animation-delay:-{j*0.21:.2f}s">{bang}<div class="{cls}"></div></div>')

LOADER = f'''<!-- 로딩 화면: art/tools/web/make_loader.py 로 생성 -->
  <style>
    @font-face{{font-family:'GowunBatangL';src:url('assets/assets/fonts/GowunBatang-Bold.ttf') format('truetype');font-weight:700;font-display:swap}}
    #ml-loader{{position:fixed;inset:0;z-index:10;background:#2c3720 url('loader-bg.jpg') center/cover no-repeat;overflow:hidden;transition:opacity .45s ease}}
    #ml-loader.done{{opacity:0;pointer-events:none}}
    #ml-stage{{position:absolute;left:50%;top:50%;width:1560px;height:720px;transform-origin:0 0}}
    #ml-title{{position:absolute;left:0;right:0;top:190px;text-align:center;font:700 96px 'GowunBatangL',serif;color:#FBF8F1;text-shadow:4px 4px 0 rgba(0,0,0,.43)}}
    #ml-bar{{position:absolute;left:{BX}px;top:{BY}px;width:{BW}px;height:{BH}px;border-radius:13px;background:#4E463A;box-shadow:0 0 0 4px #2A211C}}
    #ml-fill{{position:absolute;left:0;top:0;bottom:0;width:0;border-radius:13px;background:linear-gradient(#F8D680 0 50%,#F2C14E 50%);transition:width .35s ease}}
    #ml-run{{position:absolute;left:{BX}px;top:{BY}px;width:0;height:0;transition:left .35s ease}}
    #ml-run>div{{position:absolute}}
    #ml-msg{{position:absolute;left:0;right:0;top:{BY+52}px;text-align:center;font:400 26px system-ui,-apple-system,'Apple SD Gothic Neo','Malgun Gothic',sans-serif;color:#FBF8F1}}
    .hop{{animation:hop .42s ease-in-out infinite alternate}}
    .flee{{animation:hop .3s ease-in-out infinite alternate}}
    .float{{animation:float 1.1s ease-in-out infinite alternate}}
    @keyframes hop{{from{{transform:translateY(0)}}to{{transform:translateY(-8px)}}}}
    @keyframes float{{from{{transform:translateY(-2px)}}to{{transform:translateY(-12px)}}}}
    .bang{{position:absolute;left:50%;top:-30px;font:700 28px system-ui,sans-serif;color:#E0483E;animation:blink .5s steps(1) infinite}}
    @keyframes blink{{50%{{opacity:0}}}}
    {"".join(css)}
  </style>
  <div id="ml-loader" aria-live="polite">
    <div id="ml-stage">
      <div id="ml-title">말랑영웅전</div>
      <div id="ml-bar"><div id="ml-fill"></div></div>
      <div id="ml-run">
        {"".join(html)}
      </div>
      <div id="ml-msg">게임 엔진 불러오는 중…</div>
    </div>
  </div>
  <script>
    (function () {{
      var stage = document.getElementById('ml-stage');
      function fit() {{
        var k = Math.min(innerWidth / 1560, innerHeight / 720);
        stage.style.transform = 'scale(' + k + ') translate(-50%,-50%)';
      }}
      fit(); addEventListener('resize', fit);
      var shown = 0, fake = 0, real = -1, finished = false;
      function draw(p) {{
        shown = Math.max(shown, p);
        document.getElementById('ml-fill').style.width = (shown * 100) + '%';
        document.getElementById('ml-run').style.left = ({BX} + {BW} * shown) + 'px';
        document.getElementById('ml-msg').textContent =
          (real < 0 ? '게임 엔진 불러오는 중… ' : '그림 불러오는 중… ') + Math.round(shown * 100) + '%';
      }}
      // 엔진을 받는 동안: 0 → 45%까지 천천히 (실제 진행률은 알 수 없어서 시간으로 채움)
      var t = setInterval(function () {{
        if (real >= 0 || finished) return clearInterval(t);
        fake += (0.45 - fake) * 0.04; draw(fake);
      }}, 100);
      draw(0.02);
      // 게임(Dart)이 그림 진행률을 알려 준다: 45% → 100%
      window.mallangLoader = {{
        progress: function (p) {{
          real = p; draw(0.45 + 0.55 * p);
          if (p >= 1 && !finished) {{
            finished = true;
            setTimeout(function () {{
              var el = document.getElementById('ml-loader');
              el.classList.add('done');
              setTimeout(function () {{ el.remove(); }}, 600);
            }}, 250);
          }}
        }}
      }};
    }})();
  </script>
  <!-- /로딩 화면 -->'''

p = f'{ROOT}/web/index.html'
s = open(p, encoding='utf-8').read()
start = s.find('<!-- 로딩 화면:')
if start >= 0:
    end = s.index('<!-- /로딩 화면 -->') + len('<!-- /로딩 화면 -->')
    s = s[:start] + LOADER + s[end:]
else:
    s = s.replace('<body>\n', '<body>\n  ' + LOADER + '\n', 1)
open(p, 'w', encoding='utf-8').write(s)
print('ok', len(LOADER))
