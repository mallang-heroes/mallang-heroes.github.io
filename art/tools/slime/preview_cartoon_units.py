"""카툰 유닛을 카툰 맵 위에 실제 게임 크기로 올려 보기 (2026-11-11).
출력: art/preview/unit-cartoon/on-map.png (맵 전체) · on-map-zoom.png (가운데 확대)
실행: python3 art/tools/slime/preview_cartoon_units.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
U = os.path.join(ROOT, 'art/source/gemini/unit-cartoon/units')
TIERS = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu']
COLS = [154.5, 223.5, 292.5, 361.5, 430.5]
ROWS = [726, 594, 525, 393, 324]


def main():
    bg = Image.open(os.path.join(ROOT, 'art/source/gemini/map-cartoon/game/ground.png')).convert('RGBA')
    feet = json.load(open(os.path.join(U, 'feet.json')))
    names = sorted(feet)
    sh = Image.new('RGBA', bg.size); sd = ImageDraw.Draw(sh)
    sprites = []
    i = 0
    for r, y in enumerate(ROWS):
        for c, x in enumerate(COLS):
            if (r * 5 + c) % 3 == 2: continue           # 몇 칸은 비워 둠
            name = f'spear-{TIERS[(r + c * 3) % 4]}'
            if name not in feet: continue
            im = Image.open(os.path.join(U, name + '.png'))
            fx, fy, bw = feet[name]
            X, Y = x * 2, (y + 14) * 2
            sd.ellipse([X - bw * .85, Y - bw * .22, X + bw * .85, Y + bw * .22], fill=(30, 60, 20, 80))
            sprites.append((Y, im, int(round(X - fx)), int(round(Y - fy))))
            i += 1
    bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
    for _, im, x, y in sorted(sprites, key=lambda t: t[0]):
        bg.alpha_composite(im, (x, y))
    out = os.path.join(ROOT, 'art/preview/unit-cartoon')
    os.makedirs(out, exist_ok=True)
    bg.convert('RGB').save(os.path.join(out, 'on-map.png'))
    bg.crop((180, 560, 980, 1560)).convert('RGB').save(os.path.join(out, 'on-map-zoom.png'))
    print('ok', i)


if __name__ == '__main__':
    main()
