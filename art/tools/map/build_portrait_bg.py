"""세로 맵 배경 정리 (도트 개편).

입력: art/source/gemini/map-portrait/pixel-layout-empty.png (704×1524 화면 시안, 정보줄·트레이·배치 칸 포함)
출력 (@2x, 보드 585×834 → 1170×1668):
  assets/images/map/map-portrait-bg.png        정보줄·배치 칸을 지운 맵 (궁·동굴·나무 포함)
  assets/images/map/map-portrait-ground.png    궁·동굴까지 뺀 바닥 (궁 자리 성벽·길, 동굴 자리 길을 이어 그림)
  assets/images/map/map-portrait-palace.png    궁만 (투명, 맵과 같은 캔버스에서 잘라 낸 최소 영역)
  assets/images/map/map-portrait-cave.png      동굴만 (투명)
  assets/data/map-portrait.json                궁·동굴 그림 위치(보드 좌표), 배치 칸 자리
  art/preview/map-portrait/*.png               확인용 (위 4장의 PNG 사본, 다시 합친 그림, 마스크)
실행: python3 art/tools/map/build_portrait_bg.py && python3 art/tools/web/to_webp.py (저장소 루트에서)
"""
import json
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SRC = os.path.join(ROOT, 'art/source/gemini/map-portrait/pixel-layout-empty.png')
OUT_IMG = os.path.join(ROOT, 'assets/images/map')
OUT_DATA = os.path.join(ROOT, 'assets/data')
OUT_PREV = os.path.join(ROOT, 'art/preview/map-portrait')

# 시안(704 폭)에서 맵 영역: 트레이 위 테두리(y=1048) 바로 위까지, 보드 비율(585:834)에 맞춰 위를 자른다.
Y0, Y1 = 43, 1047
OUT_W, OUT_H = 1170, 1668          # 보드 585×834 @2x
SX = OUT_W / 704                   # 시안 px → @2x px
BOARD = 0.5 * SX                   # 시안 px → 보드 좌표

GRASS = np.array([72, 161, 123], np.uint8)   # 배치 칸 밑 평평한 풀색 (BGR)


def grass_patch(im, h, w, seed=0):
    """정보줄 밑에서 잘라 온 깨끗한 풀밭(36×480)을 뒤집어 가며 이어 붙인다."""
    p = im[64:100, 108:588]
    rng = np.random.default_rng(seed)
    rows = []
    for _ in range(h // p.shape[0] + 1):
        row = []
        for _ in range(w // p.shape[1] + 1):
            q = p
            if rng.random() < 0.5: q = q[:, ::-1]
            if rng.random() < 0.5: q = q[::-1]
            row.append(q)
        rows.append(np.concatenate(row, 1))
    return np.concatenate(rows, 0)[:h, :w]


def find_tiles(im):
    w = (im.min(2) > 205).astype(np.uint8)
    w[:120] = 0
    w[Y1:] = 0
    n, _, st, _ = cv2.connectedComponentsWithStats(w)
    return sorted([tuple(int(v) for v in st[i][:4]) for i in range(1, n) if st[i][4] > 1500],
                  key=lambda t: (t[1], t[0]))


def remove_ui(im):
    out = im.copy()
    # 정보줄 (라운드·궁 체력·은냥 / 남은 시간 / 배속 버튼)
    for x0, y0, x1, y1 in [(4, 0, 702, 66), (4, 0, 104, 121), (594, 0, 702, 94)]:
        out[y0:y1, x0:x1] = grass_patch(im, y1 - y0, x1 - x0, seed=x0)
    # 배치 칸: 하얀 칸 + 테두리 4px, 밑은 평평한 풀색
    tiles = find_tiles(im)
    for x, y, w, h in tiles:
        out[y - 4:y + h + 4, x - 4:x + w + 4] = GRASS
    # 칸 사이 틈까지 칸 무리 전체를 같은 풀색으로 (시안에 남은 작은 점 제거)
    for row in sorted({t[1] // 120 for t in tiles}):
        grp = [t for t in tiles if t[1] // 120 == row]
        x0 = min(t[0] for t in grp) - 4; x1 = max(t[0] + t[2] for t in grp) + 4
        y0 = min(t[1] for t in grp) - 4; y1 = max(t[1] + t[3] for t in grp) + 4
        out[y0:y1, x0:x1] = GRASS
    # 맨 아래 칸 줄 밑 테두리가 흙으로 끊긴 곳(시안 원본의 흠)을 옆 테두리로 메움
    out[953:976, 340:404] = out[953:976, 276:340]
    return out, tiles


def fill_holes(m):
    h, w = m.shape
    ff = m.copy()
    mask = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(ff, mask, (0, 0), 255)
    return m | cv2.bitwise_not(ff)


def largest(m):
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    if n <= 1: return m
    i = 1 + int(np.argmax(st[1:, 4]))
    return np.where(lab == i, 255, 0).astype(np.uint8)


def palace_ground(clean):
    """궁 자리 바닥: 풀밭 + 뒤 성벽(같은 무늬를 213px 왼쪽에서 가져옴) + 길을 궁 가운데까지 연장."""
    g = clean.copy()
    x0, x1, y0, y1 = 244, 462, 96, 398
    g[y0:y1, x0:x1] = grass_patch(clean, y1 - y0, x1 - x0, seed=7)
    g[150:204, x0:x1] = clean[150:204, x0 - 213:x1 - 213]
    # 왼쪽 성벽 앞 나무 두 그루가 겹치는 자리는 오른쪽 끝 성벽에서 가져온다
    g[150:204, 288:354] = clean[150:204, 630:696]
    g[150:204, 368:434] = clean[150:204, 630:696]
    strip = clean[288:398, 188:244]
    for x in range(x0, 360, strip.shape[1]):
        e = min(x + strip.shape[1], 360)
        g[288:398, x:e] = strip[:, :e - x]
    return g


def palace_mask(orig, ground):
    m = np.zeros(orig.shape[:2], np.uint8)
    d = np.abs(orig.astype(int) - ground.astype(int)).sum(2)
    reg = np.zeros_like(m)
    reg[100:394, 246:460] = 1
    reg[150:188, :259] = 0         # 두 지붕 사이 높이에선 위 지붕 폭(259~446) 밖은 성벽
    reg[150:188, 447:] = 0
    reg[172:188, :284] = 0         # 처마 아래로는 몸채(286~419)만 궁, 양옆은 뒤 성벽
    reg[172:188, 422:] = 0
    m[(d > 60) & (reg > 0)] = 255
    m[194:388, 256:449] = 255      # 아래 지붕 + 기단 안쪽 (가장자리는 차이로 잡음)
    m[160:194, 286:419] = 255      # 두 지붕 사이 몸채
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    m = fill_holes(largest(m))
    # 기단 옆에 묻어 나온 풀색 가장자리 빼기
    b, g, r = [orig[..., i].astype(int) for i in range(3)]
    greenish = (g > r + 20) & (g > b + 40)
    greenish[:215] = False
    m[greenish] = 0
    return largest(m)


def grow(m, px):
    return cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * px + 1, 2 * px + 1)))


def cave_mask(orig):
    poly = np.array([(664, 818), (704, 806), (704, 1048), (622, 1048), (624, 1030),
                     (600, 1000), (578, 990), (556, 978), (541, 962), (548, 935),
                     (575, 880), (612, 850), (645, 826)], np.int32)
    allow = np.zeros(orig.shape[:2], np.uint8)
    cv2.fillPoly(allow, [poly], 1)
    b, g, r = [orig[..., i].astype(int) for i in range(3)]
    grass = np.abs(orig.astype(int) - GRASS.astype(int)).sum(2) < 30
    sand = (r > 175) & (g > 135) & (b < 175) & (r > g + 12) & (g > b + 20)
    m = np.where((allow > 0) & ~grass & ~sand, 255, 0).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    m = largest(m)
    m = fill_holes(m)
    # 동굴 입구 앞 흙길(입 안쪽 어두운 곳은 동굴)
    return m


def cave_ground(clean, mask):
    """동굴 자리: 아래 길을 화면 오른쪽 끝까지 잇고, 나머지는 주변으로 메운다."""
    g = clean.copy()
    strip = clean[875:1047, 470:540]
    for x in range(540, 704, strip.shape[1]):
        e = min(x + strip.shape[1], 704)
        g[875:1047, x:e] = strip[:, :e - x]
    # 동굴에 가린 오른쪽 길 모퉁이: 같은 길의 위 모퉁이(y 536~620)를 위아래로 뒤집어 붙임
    g[800:886, 560:704] = clean[536:622, 560:704][::-1]
    keep = grow(mask, 4) == 0
    g[keep] = clean[keep]
    return g


def to_out(a, interp=Image.LANCZOS):
    """시안 맵 영역 → @2x 출력 크기."""
    a = a[Y0:Y1]
    if a.ndim == 3 and a.shape[2] == 3:
        im = Image.fromarray(cv2.cvtColor(a, cv2.COLOR_BGR2RGB))
    elif a.ndim == 3:
        im = Image.fromarray(cv2.cvtColor(a, cv2.COLOR_BGRA2RGBA))
    else:
        im = Image.fromarray(a)
    return im.resize((OUT_W, OUT_H), interp)


def cutout(orig, mask, name):
    rgba = cv2.cvtColor(orig, cv2.COLOR_BGR2BGRA)
    rgba[..., 3] = mask
    full = to_out(rgba)
    arr = np.asarray(full).copy()
    arr[..., 3] = np.where(arr[..., 3] > 127, 255, 0)
    full = Image.fromarray(arr)
    box = full.getbbox()
    piece = full.crop(box)
    piece.save(os.path.join(OUT_IMG, f'map-portrait-{name}.png'))
    return box, full


def main():
    os.makedirs(OUT_PREV, exist_ok=True)
    orig = cv2.imread(SRC)
    clean, tiles = remove_ui(orig)

    bg = to_out(clean)
    bg.save(os.path.join(OUT_IMG, 'map-portrait-bg.png'))

    pg = palace_ground(clean)
    pm = palace_mask(clean, pg)
    cm = cave_mask(clean)
    ground = clean.copy()
    pmg = grow(pm, 3) > 0
    ground[pmg] = pg[pmg]
    ground = cave_ground(ground, cm)
    gimg = to_out(ground)
    gimg.save(os.path.join(OUT_IMG, 'map-portrait-ground.png'))

    pbox, pfull = cutout(clean, pm, 'palace')
    cbox, cfull = cutout(clean, cm, 'cave')

    # 확인용: 바닥 + 궁 + 동굴을 다시 얹은 것 (bg와 거의 같아야 함), 마스크 겹쳐 보기
    re = gimg.convert('RGBA')
    re.alpha_composite(cfull)
    re.alpha_composite(pfull)
    re.convert('RGB').save(os.path.join(OUT_PREV, 'recomposed.png'))
    ov = np.asarray(bg).copy()
    pmo = np.asarray(Image.fromarray(pm[Y0:Y1]).resize((OUT_W, OUT_H))) > 127
    cmo = np.asarray(Image.fromarray(cm[Y0:Y1]).resize((OUT_W, OUT_H))) > 127
    ov[pmo] = (ov[pmo] * 0.5 + np.array([255, 0, 255]) * 0.5).astype(np.uint8)
    ov[cmo] = (ov[cmo] * 0.5 + np.array([0, 255, 255]) * 0.5).astype(np.uint8)
    Image.fromarray(ov).save(os.path.join(OUT_PREV, 'masks.png'))

    def box_board(b):
        return {'x': round(b[0] / 2, 1), 'y': round(b[1] / 2, 1), 'w': round((b[2] - b[0]) / 2, 1), 'h': round((b[3] - b[1]) / 2, 1)}

    sy = OUT_H / (Y1 - Y0) / 2
    sx = OUT_W / 704 / 2
    data = {
        'board': [585, 834],
        'source': 'art/source/gemini/map-portrait/pixel-layout-empty.png',
        'note': '좌표는 보드 좌표(585×834). 이미지는 @2x. 궁·동굴 그림은 rect 위치에 그대로 그리면 bg와 같아진다.',
        'palace': {'image': 'map/map-portrait-palace.webp', 'rect': box_board(pbox),
                   'foot': [round((pbox[0] + pbox[2]) / 4, 1), round(pbox[3] / 2, 1)]},
        'cave': {'image': 'map/map-portrait-cave.webp', 'rect': box_board(cbox)},
        'tile': round(77 * sx, 1),
        'tiles': [[round((x + w / 2) * sx, 1), round((y + h / 2 - Y0) * sy, 1)] for x, y, w, h in tiles],
    }
    with open(os.path.join(OUT_DATA, 'map-portrait.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    for n in ('bg', 'ground', 'palace', 'cave'):
        Image.open(os.path.join(OUT_IMG, f'map-portrait-{n}.png')).save(os.path.join(OUT_PREV, f'{n}.png'))
    print(json.dumps(data, ensure_ascii=False))


if __name__ == '__main__':
    main()
