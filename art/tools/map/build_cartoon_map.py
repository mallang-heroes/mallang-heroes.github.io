"""카툰 맵(제미나이 1차 결과) → 게임용 그림 (2026-11-11).

  ground.png     맵 전체를 보드 @2x(1170×1668)로 늘림. 궁·동굴도 바닥에 같이 그려져 있다
                 (궁은 유닛 칸보다 위에 있어 유닛과 겹치지 않으므로 따로 뗄 필요 없음).
  cave-front.png 동굴 바위만 (입구 안 어두운 곳·잔디·길 제외, 투명 배경, 같은 크기).
                 몬스터 위에 덮어서 몬스터가 동굴 안에서 걸어 나오는 것처럼 보이게 한다.
출력: art/source/gemini/map-cartoon/game/
실행: python3 art/tools/map/build_cartoon_map.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SRC = os.path.join(ROOT, 'art/source/gemini/map-cartoon/map-v1.png')
OUT = os.path.join(ROOT, 'art/source/gemini/map-cartoon/game')
W, H = 1170, 1668
CAVE = (472, 684.5, 140, 131)   # 보드 (x, y, w, h) — layout 그대로, 오른쪽·아래는 화면 밖


def main():
    os.makedirs(OUT, exist_ok=True)
    im = Image.open(SRC).convert('RGB').resize((W, H), Image.LANCZOS)
    im.save(os.path.join(OUT, 'ground.png'))
    a = np.asarray(im).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    grass = (g > r + 18) & (g > b + 12)
    sand = (r > 190) & (g > 160) & (b < 170) & (r > b + 40)
    dark = (r + g + b) < 150
    x0, y0 = int(CAVE[0] * 2) - 20, int(CAVE[1] * 2) - 20
    box = np.zeros((H, W), bool); box[y0:, x0:] = True
    rock = box & ~grass & ~sand & ~dark
    # 잔티 점·풀잎 털어 내고, 바위 덩어리 중 큰 것만
    rock = ndimage.binary_opening(rock, iterations=2)
    lab, n = ndimage.label(rock)
    sizes = ndimage.sum(rock, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 400])
    keep = ndimage.binary_closing(keep, iterations=2)
    # 바위 안 작은 구멍(어두운 틈) 메우기 — 입구처럼 큰 구멍은 그대로
    holes = ndimage.binary_fill_holes(keep) & ~keep
    hl, hn = ndimage.label(holes)
    hs = ndimage.sum(holes, hl, range(1, hn + 1))
    keep |= np.isin(hl, [i + 1 for i, s in enumerate(hs) if s < 200])
    # 입구 바닥의 어두운 띠(낮고 넓은 덩어리)는 빼기
    lab, n = ndimage.label(keep)
    for i, sl in enumerate(ndimage.find_objects(lab)):
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if h < 24 and w > 3 * h: keep[lab == i + 1] = False
    # 입구 바닥 그림자 띠: 입구 아래쪽(보드 x 489~531, y 791~812)의 어두운 부분은 덮지 않음
    fy0, fy1, fx0, fx1 = 791 * 2, 812 * 2, 489 * 2, 531 * 2
    floor = np.zeros_like(keep); floor[fy0:fy1, fx0:fx1] = True
    keep &= ~(floor & ((r + g + b) < 330))
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = a; out[..., 3] = keep * 255
    alpha = Image.fromarray(out[..., 3]).filter(ImageFilter.GaussianBlur(0.7))
    o = Image.fromarray(out); o.putalpha(alpha)
    o.crop((x0, y0, W, H)).save(os.path.join(OUT, 'cave-front.png'))
    print('cave-front origin (board):', x0 / 2, y0 / 2)


if __name__ == '__main__':
    main()
