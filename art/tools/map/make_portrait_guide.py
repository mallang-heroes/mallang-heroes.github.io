"""세로 화면(C안) 맵 레이아웃 가이드와 화면 영역도를 만든다.

좌표는 `lib/game/board.dart`의 MapData와 같아야 한다. 경로를 바꾸면 두 곳을 함께 고친다.

만드는 것
- art/source/gemini/map-portrait/map-portrait-layout-guide.png
    제미나이에 첨부할 레이아웃 (@2x 1170×1668). 단색 풀밭 + 흙길 + 동굴 자리 + 궁 마당 자리.
- art/preview/portrait/zones.png
    사람이 보는 영역도 (폰 390×844pt의 2배). 정보줄·맵·배치 칸·트레이 위치와 크기를 글자로 표시.

실행: 저장소 루트에서 `python3 art/tools/map/make_portrait_guide.py`
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]

# ── board.dart 와 같은 값 (보드 좌표 585×834) ──
BOARD_W, BOARD_H = 585, 834
ROAD_W = 60
PATH = [
    (560, 792), (66, 792), (66, 660), (519, 660), (519, 459),
    (66, 459), (66, 258), (292.5, 258), (292.5, 232),
]
CAVE = (540, 800)          # 동굴 그림 바닥 가운데
PALACE = (292.5, 240)      # 궁 그림 바닥 가운데 (궁 그림 약 141×122)
TILE, PITCH = 63, 69
COLS = [154.5, 223.5, 292.5, 361.5, 430.5]
ROWS = [726, 594, 525, 393, 324]  # 1층, 2층(아래·위), 3층(아래·위)

# ── 폰 화면 (pt) ──
PHONE_W, PHONE_H = 390, 844
TRAY_H = 264               # 트레이 내용 246 + 위아래 여백·테두리 (홈 표시줄 여백은 기기마다 더해짐)
MAP_H = PHONE_H - TRAY_H   # 580
K = PHONE_W / BOARD_W      # 보드 1px = 0.667pt (맵은 폭에 맞춰 그려짐)
MAP_TOP = (MAP_H - BOARD_H * K) / 2  # 위아래 남는 높이를 반씩 (약 12pt)

GRASS = (141, 180, 90)
ROAD = (201, 165, 122)
ROAD_EDGE = (122, 100, 70)
CAVE_COL = (70, 60, 72)
PLAZA = (198, 192, 176)


def _road(draw, s, width_scale=1.0, color=ROAD, edge=ROAD_EDGE):
    pts = [(x * s, y * s) for x, y in PATH]
    pts = [((PATH[0][0] + 60) * s, PATH[0][1] * s)] + pts  # 동굴 뒤 화면 밖까지
    w = int(ROAD_W * s * width_scale)
    draw.line(pts, fill=edge, width=w + int(6 * s), joint="curve")
    draw.line(pts, fill=color, width=w, joint="curve")
    r = w / 2
    for x, y in pts[1:-1]:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def layout_guide():
    s = 2  # @2x
    im = Image.new("RGB", (BOARD_W * s, BOARD_H * s), GRASS)
    d = ImageDraw.Draw(im)
    # 궁 마당 (궁 그림이 올라갈 돌바닥 자리)
    px, py = PALACE
    d.rounded_rectangle([(px - 95) * s, (py - 34) * s, (px + 95) * s, (py + 14) * s], radius=16 * s, fill=PLAZA)
    _road(d, s)
    # 동굴 자리 (입구가 길 끝을 향함)
    cx, cy = CAVE
    d.ellipse([(cx - 46) * s, (cy - 62) * s, (cx + 46) * s, (cy + 6) * s], fill=CAVE_COL)
    out = ROOT / "art/source/gemini/map-portrait/map-portrait-layout-guide.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


def zones():
    s = 2
    W, H = PHONE_W * s, PHONE_H * s
    im = Image.new("RGB", (W, H), (30, 24, 20))
    d = ImageDraw.Draw(im)
    font_path = ROOT / "assets/fonts/Pretendard-Bold.otf"
    f = ImageFont.truetype(str(font_path), 22)
    fs = ImageFont.truetype(str(font_path), 17)

    def b2p(x, y):  # 보드 → 영역도 픽셀
        return (x * K * s, (MAP_TOP + y * K) * s)

    # 맵 영역
    x0, y0 = b2p(0, 0)
    x1, y1 = b2p(BOARD_W, BOARD_H)
    d.rectangle([0, 0, W, MAP_H * s], fill=(110, 140, 72))
    d.rectangle([x0, y0, x1, y1], fill=GRASS)
    # 길
    pts = [b2p(*p) for p in PATH]
    pts = [b2p(PATH[0][0] + 60, PATH[0][1])] + pts
    d.line(pts, fill=ROAD, width=int(ROAD_W * K * s), joint="curve")
    # 배치 칸
    for i, y in enumerate(ROWS):
        for x in COLS:
            a = b2p(x - TILE / 2, y - TILE / 2)
            b = b2p(x + TILE / 2, y + TILE / 2)
            d.rounded_rectangle([*a, *b], radius=10, outline=(255, 240, 190), width=3)
    for label, y in [("1층 1×5 (정예)", ROWS[0] - 26), ("2층 2×5", (ROWS[1] + ROWS[2]) / 2), ("3층 2×5", (ROWS[3] + ROWS[4]) / 2)]:
        d.text(b2p(COLS[-1] + 40, y - 10), label, font=fs, fill=(255, 255, 255))
    # 궁 · 동굴
    px, py = PALACE
    d.rectangle([*b2p(px - 70, py - 122), *b2p(px + 70, py)], outline=(140, 47, 43), width=4)
    d.text(b2p(px - 30, py - 70), "궁", font=f, fill=(140, 47, 43))
    cx, cy = CAVE
    d.rectangle([*b2p(cx - 50, cy - 70), *b2p(min(cx + 50, BOARD_W), cy + 4)], outline=(120, 70, 160), width=4)
    d.text(b2p(cx - 40, cy - 64), "동굴", font=fs, fill=(255, 255, 255))
    # 정보줄
    d.rounded_rectangle([8 * s, 6 * s, (PHONE_W - 8) * s, 40 * s], radius=12 * s, outline=(242, 193, 78), width=3)
    d.text((16 * s, 13 * s), "정보줄 34pt — 라운드·시간 / 궁 체력 / 은냥 / 속도", font=fs, fill=(255, 246, 224))
    # 트레이
    ty = MAP_H * s
    d.rounded_rectangle([0, ty, W, H + 40], radius=20 * s, fill=(42, 33, 28))
    d.rounded_rectangle([8 * s, ty + 8 * s, (PHONE_W - 90) * s, ty + 254 * s], radius=14 * s, outline=(242, 193, 78), width=3)
    d.text((18 * s, ty + 20 * s), "트레이 내용 296×246pt", font=f, fill=(255, 246, 224))
    d.text((18 * s, ty + 48 * s), "막사 목록 3×2 카드 / 막사 안 / 강화 / 유물 / 효과", font=fs, fill=(233, 220, 192))
    for i, name in enumerate(["막사", "강화", "유물", "효과"]):
        yy = ty + (8 + i * 43) * s
        d.rounded_rectangle([(PHONE_W - 84) * s, yy, (PHONE_W - 8) * s, yy + 38 * s], radius=11 * s, outline=(233, 220, 192), width=3)
        d.text(((PHONE_W - 70) * s, yy + 8 * s), f"탭 {name} 76×38", font=fs, fill=(233, 220, 192))
    d.rounded_rectangle([(PHONE_W - 84) * s, ty + 180 * s, (PHONE_W - 8) * s, ty + 254 * s], radius=14 * s, outline=(242, 193, 78), width=4)
    d.text(((PHONE_W - 72) * s, ty + 205 * s), "뽑기 76×74", font=fs, fill=(242, 193, 78))
    d.text((16 * s, (MAP_H - 30) * s), f"맵: 보드 585×834 → 화면 390×556pt (보드 1px = {K:.3f}pt)", font=fs, fill=(255, 255, 255))
    out = ROOT / "art/preview/portrait/zones.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


if __name__ == "__main__":
    print(layout_guide())
    print(zones())
