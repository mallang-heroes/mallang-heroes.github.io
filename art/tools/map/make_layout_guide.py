"""새 카툰 맵용 배치 가이드 (2026-11-11).

게임 규칙(unity/Assets/Scripts/Game/Board.cs MapData)대로 길·잔디·궁·동굴 자리를 색 덩어리로 칠한다.
제미나이가 이 배치를 그대로 따라 그리게 하는 첨부용이다. 글자는 넣지 않는다.
  잔디 초록 · 길(폭 60, 모서리 둥글게) 모래색 · 궁 자리 회색 · 동굴 자리 청회색 · 맨 위 담장 띠
@2x (1170×1668, 보드 585×834).
출력: art/source/gemini/map-cartoon/layout-guide.png
실행: python3 art/tools/map/make_layout_guide.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
S = 2
W, H = 585, 834
PATH = [(512, 792), (66, 792), (66, 660), (519, 660), (519, 459), (66, 459), (66, 258), (292.5, 258), (292.5, 232)]
ROAD = 60
PALACE = (204.5, 54, 174.5, 235)   # x, y, w, h
CAVE = (472, 684.5, 140, 131)

GRASS = (124, 190, 84)
ROADC = (232, 204, 146)
PAL = (150, 150, 158)
CAVEC = (108, 122, 146)
WALL = (96, 104, 118)


def main():
    im = Image.new('RGB', (W * S, H * S), GRASS)
    d = ImageDraw.Draw(im)
    # 담장 띠 (궁 뒤)
    d.rectangle([0, 72 * S, W * S, 96 * S], fill=WALL)
    # 길
    r = ROAD / 2 * S
    pts = [(x * S, y * S) for x, y in PATH]
    for a, b in zip(pts, pts[1:]):
        d.line([a, b], fill=ROADC, width=int(ROAD * S))
    for x, y in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=ROADC)
    # 길은 동굴 쪽으로 화면 끝까지
    x, y = pts[0]
    d.rectangle([x, y - r, W * S, y + r], fill=ROADC)
    # 궁
    px, py, pw, ph = PALACE
    d.rounded_rectangle([px * S, py * S, (px + pw) * S, (py + ph) * S], radius=10 * S, fill=PAL)
    # 동굴 (화면 오른쪽 아래로 넘어감)
    cx, cy, cw, ch = CAVE
    d.ellipse([cx * S, cy * S, (cx + cw) * S, (cy + ch + 60) * S], fill=CAVEC)
    out = os.path.join(ROOT, 'art/source/gemini/map-cartoon')
    os.makedirs(out, exist_ok=True)
    im.save(os.path.join(out, 'layout-guide.png'))
    print('ok')


if __name__ == '__main__':
    main()
