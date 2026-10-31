"""도트 동굴 → 세로 맵에 넣기.

입력: art/source/gemini/map-portrait/cave-pixel.png (제미나이, 하늘색 #00FFFF 배경, 1도트 = 4px)
      assets/images/map/map-portrait-ground.png|webp, map-portrait-palace.*  (build_portrait_bg.py 결과)
출력: assets/images/map/map-portrait-cave.png        동굴 정지 그림 (투명, @2x)
      assets/images/map/map-portrait-cave-glow.png   입구 반짝임 4프레임 시트 + .json (TexturePacker Hash + anchor)
      assets/images/map/map-portrait-bg.png          바닥 + 도트 동굴 + 궁을 다시 합친 맵
      assets/data/map-portrait.json                  cave 항목(rect·foot·mouth) 갱신
      art/preview/map-portrait/cave-*.png|gif       확인용
build_portrait_bg.py 가 끝에서 이 스크립트를 부른다 (따로 실행해도 됨).
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SRC = os.path.join(ROOT, 'art/source/gemini/map-portrait/cave-pixel.png')
IMG = os.path.join(ROOT, 'assets/images/map')
DATA = os.path.join(ROOT, 'assets/data/map-portrait.json')
PREV = os.path.join(ROOT, 'art/preview/map-portrait')

DOT, SX, SY = 4, 0, 1          # 제미나이 그림의 도트 크기와 격자 시작점
WIDTH_BOARD = 140              # 동굴 폭 (보드 좌표). 궁은 약 175
MOUTH_X_BOARD = 512            # 입구 가운데 x
MOUTH_FLOOR_BOARD = 812        # 입구 바닥 y (아래 길 띠 762~824 안쪽 아래)
FRAMES, FRAME_MS = 4, 180


def load_dots():
    a = np.asarray(Image.open(SRC).convert('RGB')).astype(int)
    h, w = a.shape[:2]
    ny, nx = (h - SY) // DOT, (w - SX) // DOT
    c = a[SY:SY + ny * DOT, SX:SX + nx * DOT].reshape(ny, DOT, nx, DOT, 3)
    dots = np.median(c[:, 1:3, :, 1:3].transpose(0, 2, 1, 3, 4).reshape(ny, nx, 4, 3), axis=2).astype(np.uint8)
    r, g, b = [dots[..., i].astype(int) for i in range(3)]
    bg = (g > 225) & (b > 225) & (r < 110)   # 하늘색 배경 (바위 밝은 면과 겹치지 않게 좁게)
    # 가장 큰 덩어리만 (오른쪽 아래 제미나이 표시 등 제거)
    from scipy import ndimage
    lab, n = ndimage.label(~bg)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    keep = lab == (1 + int(np.argmax(sizes)))
    keep = ndimage.binary_fill_holes(keep)
    # 가장자리에 남은 하늘색 섞인 도트 벗기기
    for _ in range(2):
        edge = keep & ~ndimage.binary_erosion(keep)
        cyan = edge & (b > r + 70) & (g > r + 70) & (g > 140)
        keep &= ~cyan
    ys, xs = np.where(keep)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return dots[y0:y1, x0:x1], keep[y0:y1, x0:x1]


def find_mouth(dots, keep):
    """입구(어두운 남보라 영역)의 바닥 가운데와 반짝이 위치."""
    d = dots.astype(int)
    lum = d.mean(2)
    dark = keep & (lum < 60)
    from scipy import ndimage
    lab, n = ndimage.label(dark)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    mouth = lab == (1 + int(np.argmax(sizes)))
    r, g, b = d[..., 0], d[..., 1], d[..., 2]
    spark = keep & (b > 120) & (r > 90) & (g < 110) & (b > g + 50)
    # 입구 안(입구를 조금 넓힌 상자 안)에 있는 것만
    ys, xs = np.where(mouth)
    box = (ys.min(), ys.max(), xs.min(), xs.max())
    sy, sx = np.where(spark)
    inside = (sy >= box[0]) & (sy <= box[1]) & (sx >= box[2]) & (sx <= box[3])
    spark_pts = list(zip(sy[inside], sx[inside]))
    mouth_fill = np.median(d[mouth & ~spark], axis=0).astype(np.uint8)
    floor_y = ys.max() + 1
    cx = (xs.min() + xs.max() + 1) / 2
    return mouth, spark_pts, mouth_fill, (cx, floor_y), box


def frame_dots(dots, spark_pts, fill, t):
    """t번째 프레임: 반짝이마다 위상을 달리해 켜짐·반·꺼짐."""
    out = dots.copy()
    levels = [1.0, 0.55, 0.0, 0.55]
    # 서로 붙은 반짝이 픽셀은 같은 위상
    groups = {}
    for (y, x) in spark_pts:
        key = (y // 3, x // 3)
        groups.setdefault(key, []).append((y, x))
    for i, (_, pts) in enumerate(sorted(groups.items())):
        k = levels[(t + i * 3) % len(levels)]
        for (y, x) in pts:
            out[y, x] = (dots[y, x] * k + fill * (1 - k)).astype(np.uint8)
    return out


def to_rgba(dots, keep, scale_px):
    """도트 → @2x 픽셀 (부드럽게 줄임, 가장자리 배경색 번짐 없게)."""
    rgb = dots.copy()
    rgb[~keep] = (42, 33, 28)   # 외곽선 색으로 채워 두고 줄임
    h, w = keep.shape
    W = round(w * scale_px); H = round(h * scale_px)
    big = Image.fromarray(rgb).resize((w * 8, h * 8), Image.NEAREST).resize((W, H), Image.LANCZOS)
    al = Image.fromarray((keep * 255).astype(np.uint8)).resize((w * 8, h * 8), Image.NEAREST).resize((W, H), Image.BOX)
    im = big.convert('RGBA')
    im.putalpha(al)
    return im


def main():
    dots, keep = load_dots()
    mouth, spark_pts, fill, (mcx, mfloor), box = find_mouth(dots, keep)
    h, w = keep.shape
    px = WIDTH_BOARD * 2 / w                 # @2x 픽셀 / 도트
    # 정지 그림
    still = to_rgba(dots, keep, px)
    still.save(os.path.join(IMG, 'map-portrait-cave.png'))
    # 보드 위 위치: 입구 바닥 가운데를 (MOUTH_X, MOUTH_FLOOR)에
    left = MOUTH_X_BOARD - mcx * px / 2
    top = MOUTH_FLOOR_BOARD - mfloor * px / 2
    W2, H2 = still.size
    # 반짝임 시트
    frames = [to_rgba(frame_dots(dots, spark_pts, fill, t), keep, px) for t in range(FRAMES)]
    sheet = Image.new('RGBA', (W2 * FRAMES, H2))
    meta_frames = {}
    foot = (round(mcx * px / W2, 4), round(mfloor * px / H2, 4))
    for t, f in enumerate(frames):
        sheet.paste(f, (t * W2, 0))
        meta_frames[f'map-portrait-cave-glow-{t}'] = {
            'frame': {'x': t * W2, 'y': 0, 'w': W2, 'h': H2}, 'duration': FRAME_MS,
            'anchor': {'x': foot[0], 'y': foot[1]}}
    sheet.save(os.path.join(IMG, 'map-portrait-cave-glow.png'))
    with open(os.path.join(IMG, 'map-portrait-cave-glow.json'), 'w', encoding='utf-8') as f:
        json.dump({'frames': meta_frames, 'meta': {'image': 'map-portrait-cave-glow.png', 'size': {'w': W2 * FRAMES, 'h': H2},
                   'scale': '2', 'note': 'anchor = 입구 바닥 가운데. 보드 좌표 cave.mouth 에 그린다.'}}, f, ensure_ascii=False, indent=1)

    # 맵 다시 합치기: 바닥 → 동굴 → 궁
    def open_any(name):
        for ext in ('png', 'webp'):
            p = os.path.join(IMG, f'{name}.{ext}')
            if os.path.exists(p): return Image.open(p).convert('RGBA')
    ground = open_any('map-portrait-ground')
    palace = open_any('map-portrait-palace')
    with open(DATA, encoding='utf-8') as f:
        data = json.load(f)
    pr = data['palace']['rect']
    bg = ground.copy()
    bg.alpha_composite(still, (round(left * 2), round(top * 2)))
    bg.alpha_composite(palace, (round(pr['x'] * 2), round(pr['y'] * 2)))
    bg.convert('RGB').save(os.path.join(IMG, 'map-portrait-bg.png'))

    data['cave'] = {
        'image': 'map/map-portrait-cave.webp', 'glow': 'map/map-portrait-cave-glow.json',
        'rect': {'x': round(left, 1), 'y': round(top, 1), 'w': round(W2 / 2, 1), 'h': round(H2 / 2, 1)},
        'mouth': [MOUTH_X_BOARD, MOUTH_FLOOR_BOARD],
        'mouth_width': round((box[3] - box[2] + 1) * px / 2, 1),
        'note': '도트 동굴(cave-pixel.png). 오른쪽 일부는 화면 밖. 몬스터 출발점을 mouth 근처로 옮기면 입구에서 나오는 것처럼 보인다.'}
    with open(DATA, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)

    # 확인용
    os.makedirs(PREV, exist_ok=True)
    bg.convert('RGB').save(os.path.join(PREV, 'bg.png'))
    still.save(os.path.join(PREV, 'cave.png'))
    z = 3
    crop = (round(left * 2) - 60, round(top * 2) - 60, 1170, 1668)
    gif = []
    for f in frames:
        b = ground.copy(); b.alpha_composite(f, (round(left * 2), round(top * 2)))
        c = b.crop(crop)
        gif.append(c.resize((c.width * z // 2, c.height * z // 2), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    gif[0].save(os.path.join(PREV, 'cave-glow.gif'), save_all=True, append_images=gif[1:], duration=FRAME_MS, loop=0)
    print('cave', still.size, 'rect', data['cave']['rect'], 'mouth w', data['cave']['mouth_width'], 'sparks', len(spark_pts))


if __name__ == '__main__':
    main()
