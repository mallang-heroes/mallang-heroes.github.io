#!/usr/bin/env python3
"""제미나이 몬스터 소스(시안·표정·조각) → 게임용 스프라이트 시트 + JSON.

사용: python3 art/tools/monster/build_monsters.py [mob-boar boss-tiger ...]
입력: art/source/gemini/monsters/m<번호>-<이름>-{ref,face,parts}.png
출력: assets/images/monsters/<이름>/<이름>[-walk|-hit|-die|-appear].{png,json}
      art/preview/monsters/ (GIF·길 위 미리보기)

방식: 시안 한 장(전신)을 다리·꼬리·몸통으로 오려 컷아웃 리깅한다.
 - 다리: 다각형으로 지정한 영역을 몸통에서 떼어 엉덩이·어깨 쪽 회전축으로 흔든다.
         윗부분은 몸통 뒤로 겹치게(OV px) 더 잘라서 돌려도 틈이 안 보인다.
 - 꼬리: 다각형(멧돼지·호랑이) 또는 '몸통 다각형 바깥 전부'(구미호)로 떼어 흔든다.
 - 표정: 표정 시트(2×2: 기본·아야·어지러움·포효)의 머리를 시안 머리 위치에 맞춰 덮어쓴다.
 - 대왕 멧돼지는 시안 원본이 없어 조각 시트로 몸통과 다리를 직접 조립한다.
좌표는 모두 제미나이 원본(1024×1024) 픽셀 기준.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "art", "tools", "slime"))
from keying import key_out  # noqa: E402

SRC = os.path.join(ROOT, "art", "source", "gemini", "monsters")
OUT = os.path.join(ROOT, "assets", "images", "monsters")
PREV = os.path.join(ROOT, "art", "preview", "monsters")
OV = 28            # 다리 윗부분을 몸통 뒤로 더 자르는 길이 (원본 px)
OUTLINE = (42, 33, 28)

# ---------------------------------------------------------------- 몬스터 설정
# legs: (이름, 다각형, 위상 0/0.5, 앞/뒤 레이어 'far'|'near')
TIGER_LEGS = [
    ("hind_far",  [(333, 700), (497, 700), (497, 848), (333, 848)], 0.5, "far"),
    ("front_far", [(700, 700), (838, 700), (838, 852), (700, 852)], 0.0, "far"),
    ("hind_near", [(140, 700), (276, 700), (276, 858), (140, 858)], 0.0, "near"),
    ("front_near", [(500, 722), (676, 722), (676, 888), (480, 888), (480, 780)], 0.5, "near"),
]
TIGER_TAIL = [(18, 440), (150, 440), (160, 470), (172, 520), (174, 600), (170, 650), (155, 700), (140, 742), (18, 742)]

FOX_LEGS = {
    "mob-gumiho": [
        ("hind_far",  [(478, 724), (598, 724), (598, 860), (478, 860)], 0.5, "far"),
        ("front_far", [(735, 728), (812, 728), (812, 866), (735, 866)], 0.0, "far"),
        ("hind_near", [(333, 728), (420, 728), (420, 874), (333, 874)], 0.0, "near"),
        ("front_near", [(600, 734), (722, 734), (722, 906), (600, 906)], 0.5, "near"),
    ],
    "boss-gumiho": [
        ("hind_far",  [(480, 734), (606, 734), (606, 874), (480, 874)], 0.5, "far"),
        ("front_far", [(760, 734), (848, 734), (848, 878), (760, 878)], 0.0, "far"),
        ("hind_near", [(328, 744), (421, 744), (421, 894), (328, 894)], 0.0, "near"),
        ("front_near", [(606, 744), (754, 744), (754, 924), (606, 924)], 0.5, "near"),
    ],
}
FOX_BODY = {
    "mob-gumiho": [(395, 600), (410, 556), (500, 546), (600, 546), (636, 505), (640, 330), (690, 318),
                   (722, 392), (800, 372), (880, 312), (905, 330), (912, 620), (880, 690), (840, 740),
                   (822, 880), (560, 912), (325, 885), (334, 722), (378, 652)],
    "boss-gumiho": [(395, 610), (410, 556), (500, 546), (622, 542), (680, 470), (700, 400), (728, 300),
                    (764, 284), (800, 300), (905, 288), (918, 330), (942, 500), (872, 562), (862, 700),
                    (852, 784), (852, 902), (560, 932), (322, 900), (332, 724), (378, 652)],
}

MONSTERS = {
    "mob-boar": dict(code="m1", file="m1-boar", key="magenta", boss=False, base="parts", base_crop=(20, 185, 945, 885),
                     legs=[("hind_far",  [(325, 700), (452, 700), (452, 830), (325, 830)], 0.5, "far"),
                           ("front_far", [(655, 690), (762, 690), (762, 840), (655, 840)], 0.0, "far"),
                           ("front_near", [(490, 705), (612, 705), (612, 874), (490, 874)], 0.5, "near")],
                     tail=("poly", [(22, 398), (170, 398), (166, 512), (22, 512)], (165, 468)),
                     head=(460, 195, 936, 612), swing=13),
    "boss-boar": dict(code="m2", file="m2-boss-boar", key="magenta", boss=True, base="ref",
                      legs=[("hind_far",  [(330, 700), (450, 700), (450, 828), (330, 828)], 0.5, "far"),
                            ("front_far", [(655, 700), (758, 700), (758, 836), (655, 836)], 0.0, "far"),
                            ("hind_near", [(140, 706), (262, 706), (262, 852), (140, 852)], 0.0, "near"),
                            ("front_near", [(492, 712), (612, 712), (612, 874), (492, 874)], 0.5, "near")],
                      tail=None, head=(596, 214, 992, 692), head_scale=1.14, erase=[(760, 330, 1000, 700), (640, 360, 760, 700)], erase_gold=True, swing=11),
    "mob-tiger": dict(code="m3", file="m3-tiger", key="magenta", boss=False, base="ref",
                      legs=TIGER_LEGS, tail=("poly", TIGER_TAIL, (166, 492)),
                      head=(555, 200, 956, 594), swing=15),
    "boss-tiger": dict(code="m4", file="m4-boss-tiger", key="magenta", boss=True, base="ref",
                       legs=TIGER_LEGS, tail=("poly", TIGER_TAIL, (166, 492)),
                       head=(610, 180, 960, 600), swing=12),
    "mob-gumiho": dict(code="m5", file="m5-fox", key="green", boss=False, base="ref",
                       legs=FOX_LEGS["mob-gumiho"], tail=("outside", FOX_BODY["mob-gumiho"], (430, 600)), tail_flames=True,
                       head=(628, 312, 912, 618), swing=16, body_width=600),
    "boss-gumiho": dict(code="m6", file="m6-boss-fox", key="green", boss=True, base="ref",
                        legs=FOX_LEGS["boss-gumiho"], tail=("outside", FOX_BODY["boss-gumiho"], (430, 610)), tail_flames=True,
                        head=(676, 282, 944, 604), swing=13, body_width=620),
    "mob-dokkaebi": dict(code="m7", file="m7-dokkaebi", key="magenta", boss=False, base="ref", legs_behind=True,
                         legs=[("back_leg", [(285, 772), (502, 772), (482, 862), (445, 952), (262, 952), (262, 800)], 0.0, "far"),
                               ("front_leg", [(508, 776), (700, 776), (770, 900), (772, 934), (586, 934), (556, 860)], 0.5, "near")],
                         arms=[("front_arm", [(684, 562), (760, 590), (790, 724), (690, 730), (672, 640)], 0.0)],
                         tail=None, head=(338, 98, 732, 458), swing=18, arm_swing=10),
    "boss-dokkaebi": dict(code="m8", file="m8-boss-dokkaebi", key="magenta", boss=True, base="ref", legs_behind=True,
                          peel_white=True, erase=(560, 40, 800, 470), match_skin=True,
                          legs=[("back_leg", [(244, 800), (300, 794), (420, 842), (424, 972), (244, 972)], 0.0, "far"),
                                ("front_leg", [(666, 776), (742, 768), (812, 936), (806, 960), (612, 960), (624, 890), (666, 862)], 0.5, "near")],
                          arms=[("front_arm", [(762, 556), (862, 596), (892, 700), (874, 778), (770, 778), (748, 640)], 0.0)],
                          tail=None, head=(330, 48, 772, 578), swing=13, arm_swing=8),
    "mob-ghost": dict(code="m9", file="m9-ghost", key="green", boss=False, base="ref", float=True,
                      legs=[], anchor=(520, 905),
                      tail=("poly", [(190, 740), (330, 740), (372, 842), (360, 912), (190, 912)], (362, 840)),
                      head=(428, 92, 690, 400), erase=(540, 180, 700, 380), swing=0),
    "boss-ghost": dict(code="m10", file="m10-boss-ghost", key="green", boss=True, base="ref", float=True,
                       legs=[], anchor=(560, 770), body_width=680,
                       orbit=[(190, 360, 295, 530), (750, 255, 850, 410), (795, 535, 900, 710)],
                       tail=("poly", [(90, 575), (330, 575), (392, 640), (392, 712), (90, 712)], (388, 662)),
                       head=(560, 242, 700, 404), erase=(590, 285, 705, 404), swing=0),
    "mob-zombie": dict(code="m11", file="m11-zombie", key="magenta", boss=False, base="ref", legs_behind=True,
                       legs=[("back_leg", [(372, 648), (472, 648), (472, 778), (342, 778), (342, 690)], 0.0, "far"),
                             ("front_leg", [(515, 655), (612, 655), (672, 695), (672, 762), (572, 762), (528, 722)], 0.5, "near")],
                       arms=[("arms", [(586, 442), (756, 442), (756, 500), (690, 552), (586, 552)], 0.0, (598, 478))],
                       tail=None, head=(398, 250, 640, 474), erase=(440, 250, 645, 474), swing=14, arm_swing=6),
    "boss-zombie-king": dict(code="m12", file="m12-zombie-king", key="magenta", boss=True, base="ref", legs_behind=True,
                             frame=(96, 100),
                             legs=[("back_leg", [(348, 692), (432, 692), (432, 780), (348, 780)], 0.0, "far"),
                                   ("front_leg", [(596, 690), (702, 690), (702, 770), (596, 770)], 0.5, "near")],
                             arms=[("left_tablet", [(178, 328), (318, 328), (318, 562), (178, 562)], 0.0, (310, 470)),
                                   ("right_tablet", [(760, 316), (886, 316), (886, 530), (760, 530)], 0.5, (772, 450))],
                             tail=None, head=(448, 238, 612, 452), erase=[(478, 228, 616, 400), (446, 228, 478, 366)], swing=10, arm_swing=5),
}
FRAME = {False: (40, 44), True: (72, 76)}   # 보드 px, @2x로 내보냄


# ---------------------------------------------------------------- 공통 함수
def arr(img):
    return np.asarray(img).copy()


def poly_mask(shape, pts):
    m = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.asarray(m) > 0


def with_alpha(a, mask):
    b = a.copy()
    b[..., 3] = np.where(mask, b[..., 3], 0)
    return b


def inpaint(a, mask):
    """mask 영역을 가장 가까운 바깥 픽셀 색으로 채우고 살짝 흐림."""
    if not mask.any():
        return a
    _, (iy, ix) = ndimage.distance_transform_edt(mask, return_indices=True)
    filled = a[iy, ix]
    out = a.copy()
    out[mask] = filled[mask]
    blur = np.asarray(Image.fromarray(out, "RGBA").filter(ImageFilter.GaussianBlur(2)))
    grown = ndimage.binary_dilation(mask, iterations=2)
    out[grown, :3] = blur[grown, :3]
    return out


def defringe(a, key):
    """배경색이 남은 외곽 테두리를 외곽선 색으로."""
    solid = a[..., 3] > 0
    inner = ndimage.binary_erosion(solid, iterations=3)
    edge = solid & ~inner
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    tint = (np.minimum(r, b) - g > 25) if key == "magenta" else (g - np.maximum(r, b) > 18)
    fix = edge & tint
    out = a.copy()
    for i, c in enumerate(OUTLINE):
        out[..., i] = np.where(fix, (out[..., i] * 0.35 + c * 0.65).astype(np.uint8), out[..., i])
    return out


def largest(a, min_area=0):
    m = a[..., 3] > 40
    lab, n = ndimage.label(m)
    if n == 0:
        return None
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    i = int(np.argmax(sizes)) + 1
    keep = ndimage.binary_dilation(lab == i, iterations=2)
    b = with_alpha(a, keep)
    ys, xs = np.where(b[..., 3] > 0)
    return b[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def peel_white(a):
    """머리 둘레의 흰 스티커 테두리(+그 바깥 선)를 걷어 냄.
    흰색을 뺀 가장 큰 덩어리(머리)만 남기고, 그 안의 흰 부분(이·눈)은 구멍 메우기로 되살림."""
    rgb = a[..., :3].astype(int)
    solid = a[..., 3] > 40
    white = (rgb.min(-1) > 185) & (rgb.max(-1) - rgb.min(-1) < 50)
    core = ndimage.binary_opening(solid & ~white, iterations=3)
    lab, n = ndimage.label(core)
    if n == 0:
        return a
    sizes = ndimage.sum(core, lab, range(1, n + 1))
    head = ndimage.binary_dilation(lab == int(np.argmax(sizes)) + 1, iterations=3) & solid & ~white
    head = ndimage.binary_fill_holes(head)
    return with_alpha(a, ndimage.binary_dilation(head, iterations=1))


def faces(cfg):
    """표정 시트 2×2 → {'normal','ouch','dizzy','roar'} 잘린 머리 RGBA 배열."""
    im = arr(key_out(os.path.join(SRC, cfg["file"] + "-face.png"), cfg["key"]))
    h, w = im.shape[:2]
    out = {}
    for col, (top, bot) in ((0, ("normal", "dizzy")), (1, ("ouch", "roar"))):
        half = im[:, col * w // 2:(col + 1) * w // 2]
        # 위·아래 머리가 맞닿아 있을 수 있어, 가장 얇은 가로줄에서 나눔
        rows = (half[..., 3] > 60).sum(1)
        cut = 380 + int(np.argmin(rows[380:660]))
        for k, part in ((top, half[:cut]), (bot, half[cut:])):
            if cfg.get("peel_white"):
                part = peel_white(part)
            out[k] = defringe(largest(part), cfg["key"])
    return out


def paste(dst, src, x, y):
    """RGBA 배열 src를 dst 위 (x,y)에 알파 합성."""
    d = Image.fromarray(dst, "RGBA")
    d.alpha_composite(Image.fromarray(src, "RGBA"), (int(round(x)), int(round(y))))
    return np.asarray(d).copy()


def fit_head(head, box, k=1.03):
    """표정 머리를 시안 머리 상자에 맞춤: 가로폭으로 크기, 오른쪽·아래로 정렬."""
    x0, y0, x1, y1 = box
    s = (x1 - x0) / head.shape[1] * k
    im = Image.fromarray(head, "RGBA")
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    return np.asarray(im), x1 - im.width + 4, y1 - im.height + 4


# ---------------------------------------------------------------- 대왕 멧돼지 조립
def assemble_boss_boar(cfg):
    sheet = arr(key_out(os.path.join(SRC, cfg["file"] + "-parts.png"), "magenta"))
    r, g, b = [sheet[..., i].astype(int) for i in range(3)]
    tab = (sheet[..., 3] > 0) & (r > 185) & (r - g > 35) & (b - g > 10) & (r >= b - 10)
    tab = ndimage.binary_dilation(tab, iterations=6)
    sheet[..., 3] = np.where(tab, 0, sheet[..., 3])
    # 고정 핀 구멍(투명해진 작은 구멍)을 메움
    solid = sheet[..., 3] > 30
    holes = ndimage.binary_fill_holes(solid) & ~solid
    sheet[..., 3] = np.where(holes, 255, sheet[..., 3])
    sheet = inpaint(sheet, ndimage.binary_dilation(holes, iterations=3))
    # 핀 자국(점)과 몸통의 투명 테이프 자리
    yy, xx = np.mgrid[:sheet.shape[0], :sheet.shape[1]]
    spots = np.zeros(sheet.shape[:2], bool)
    for cx, cy in [(210, 650), (397, 678), (670, 606), (878, 635), (270, 430), (513, 461), (903, 903), (912, 915)]:
        spots |= (xx - cx) ** 2 + (yy - cy) ** 2 < 15 ** 2
    for x0, y0, x1, y1 in [(222, 385, 318, 474), (478, 418, 552, 504)]:
        spots[y0:y1, x0:x1] = True
    spots &= sheet[..., 3] > 0
    sheet = inpaint(sheet, spots)

    def piece(box):
        x0, y0, x1, y1 = box
        p = sheet[y0:y1, x0:x1].copy()
        return largest(p), x0, y0

    body, bx, by = piece((150, 100, 985, 548))
    legs_src = {"A": (95, 560, 300, 945), "B": (312, 585, 480, 946), "C": (536, 515, 766, 945), "D": (785, 540, 962, 941)}
    place = {"hind_far": ("B", 300, 318), "front_far": ("C", 565, 272),
             "hind_near": ("A", 200, 312), "front_near": ("D", 645, 292)}
    W = 1100
    canvas_layers = {}
    for name, (k, px, py) in place.items():
        p, _, _ = piece(legs_src[k])
        c = np.zeros((W, W, 4), np.uint8)
        c = paste(c, p, px, py)
        canvas_layers[name] = (c, (px + p.shape[1] / 2, py + 40), p.shape, (px, py))
    tail, _, _ = piece((50, 390, 210, 560))
    tl = np.zeros((W, W, 4), np.uint8)
    tl = paste(tl, tail, 205 - tail.shape[1] + 18, 290 - tail.shape[0] + 30)
    bd = np.zeros((W, W, 4), np.uint8)
    bd = paste(bd, body, bx + 20, by)   # 고리를 지운 만큼 몸통 왼쪽이 비어 살짝 이동 없음 보정
    # 금관: 표정 기본 머리의 금관을 몸통 머리에 얹음
    return bd, canvas_layers, tl


def crown_from_face(cfg, face_normal, head_box):
    a = face_normal.astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    gold = (al > 200) & (r > 150) & (g > 100) & (b < 110) & (r - b > 90) & (g - b > 40)
    lab, n = ndimage.label(ndimage.binary_closing(gold, iterations=3))
    sizes = ndimage.sum(gold, lab, range(1, n + 1))
    m = lab == (int(np.argmax(sizes)) + 1)
    m = ndimage.binary_fill_holes(ndimage.binary_dilation(m, iterations=5)) & (al > 0)
    ys, xs = np.where(m)
    crop = with_alpha(face_normal, m)[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return crop, xs.min(), ys.min()


# ---------------------------------------------------------------- 리그 만들기
def build_rig(name, cfg):
    fc = faces(cfg)
    W = 1100
    if cfg["base"] == "assemble":
        body, leg_layers, tail_layer = assemble_boss_boar(cfg)
        legs = []
        for lname, (layer, pivot, shape, pos) in leg_layers.items():
            phase = {"hind_far": .5, "front_far": 0, "hind_near": 0, "front_near": .5}[lname]
            side = "far" if "far" in lname else "near"
            legs.append(dict(name=lname, img=layer, pivot=pivot, phase=phase, side=side,
                             bottom=pos[1] + shape[0], cx=pivot[0]))
        tail = dict(img=tail_layer, pivot=(205, 300))
        # 금관
        crown, cx, cy = crown_from_face(cfg, fc["normal"], cfg["head"])
        hb = cfg["head"]
        s = (hb[2] - hb[0]) / fc["normal"].shape[1] * 1.03
        ci = Image.fromarray(crown, "RGBA")
        ci = ci.resize((round(ci.width * s), round(ci.height * s)), Image.LANCZOS)
        hx = hb[2] - fc["normal"].shape[1] * s + 4
        hy = hb[3] - fc["normal"].shape[0] * s + 4
        body = paste(body, np.asarray(ci), hx + cx * s, hy + cy * s)
    else:
        src = "ref" if cfg["base"] == "ref" else "parts"
        whole = arr(key_out(os.path.join(SRC, f"{cfg['file']}-{src}.png"), cfg["key"]))
        if cfg.get("base_crop"):
            x0, y0, x1, y1 = cfg["base_crop"]
            keep = np.zeros(whole.shape[:2], bool)
            keep[y0:y1, x0:x1] = True
            lab, n = ndimage.label(whole[..., 3] > 30)
            ids = set(np.unique(lab[keep & (whole[..., 3] > 30)])) - {0}
            sizes = {i: (lab == i).sum() for i in ids}
            main = max(sizes, key=sizes.get)
            whole = with_alpha(whole, ndimage.binary_dilation(lab == main, iterations=2) & keep)
        lab, n = ndimage.label(whole[..., 3] > 30)
        if n >= 1:
            sizes = ndimage.sum(whole[..., 3] > 30, lab, range(1, n + 1))
            keep = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v > sizes.max() * 0.02])
            whole = with_alpha(whole, ndimage.binary_dilation(keep, iterations=2))
        whole = defringe(whole, cfg["key"])
        big = np.zeros((W, W, 4), np.uint8)
        big[:1024, :1024] = whole
        whole = big
        alpha = whole[..., 3] > 0
        body_mask = alpha.copy()
        legs = []
        for lname, pts, phase, side in cfg["legs"]:
            pm = poly_mask(alpha.shape, pts)
            leg_px = pm & alpha
            body_mask &= ~leg_px
            up = pm.copy()
            for k in range(1, OV + 1):
                up |= np.roll(pm, -k, axis=0)
            top = min(p[1] for p in pts)
            xs = [p[0] for p in pts if p[1] == top] or [p[0] for p in pts]
            pivot = ((min(xs) + max(xs)) / 2, top + 6)
            ys, _ = np.where(leg_px)
            legs.append(dict(name=lname, img=with_alpha(whole, up & alpha), pivot=pivot, phase=phase,
                             side=side, bottom=int(ys.max()), cx=pivot[0]))
        arms = []
        for aname, pts, phase, *pv in cfg.get("arms", []):
            pm = poly_mask(alpha.shape, pts)
            arm_px = pm & alpha & body_mask
            body_mask &= ~arm_px
            up = pm.copy()
            for k in range(1, 18):
                up |= np.roll(pm, -k, axis=0)
            top = min(p[1] for p in pts)
            xs = [p[0] for p in pts if p[1] == top] or [p[0] for p in pts]
            arms.append(dict(name=aname, img=with_alpha(whole, up & alpha), phase=phase,
                             pivot=pv[0] if pv else ((min(xs) + max(xs)) / 2, top + 4)))
        orbit = []
        for box in cfg.get("orbit", []):
            x0, y0, x1, y1 = box
            m = np.zeros(alpha.shape, bool)
            m[y0:y1, x0:x1] = True
            m &= alpha & body_mask
            body_mask &= ~m
            orbit.append(with_alpha(whole, m))
        if cfg.get("tail"):
            kind, pts, pivot = cfg["tail"]
            pm = poly_mask(alpha.shape, pts)
            tmask = (pm if kind == "poly" else ~pm) & alpha & body_mask
            body_mask &= ~tmask
            tail = dict(img=with_alpha(whole, tmask), pivot=pivot)
            if cfg.get("tail_flames"):
                t = tail["img"].astype(int)
                fl = (t[..., 3] > 0) & (t[..., 2] - t[..., 0] > 28) & (t[..., 1] > t[..., 0])
                fl = ndimage.binary_dilation(ndimage.binary_opening(fl, iterations=2), iterations=3) & (t[..., 3] > 0)
                tail["flame"] = with_alpha(tail["img"], fl)
                tail["img"] = with_alpha(tail["img"], ~fl)
        else:
            tail = dict(img=np.zeros_like(whole), pivot=(0, 0))
        body = with_alpha(whole, body_mask)

    # 표정별 몸통 (머리 덮어쓰기)
    bodies = {"normal": body}
    hx0, hy0, hx1, hy1 = cfg["head"]

    def skin(img):
        """피부·털 바탕색: 외곽선·머리카락(어두움)과 하이라이트를 뺀 가장 흔한 색 무리."""
        px = img[img[..., 3] > 220][:, :3].astype(np.float32)
        lum = px.mean(1)
        px = px[(lum > 60) & (lum < 235)]
        if len(px) < 50:
            return None
        q = (px // 24).astype(int)
        keys, inv, cnt = np.unique(q, axis=0, return_inverse=True, return_counts=True)
        top = np.argsort(cnt)[-3:]
        sel = np.isin(inv.ravel(), top)
        return px[sel].mean(0)

    if cfg.get("match_skin"):
        rs, fs = skin(body[hy0:hy1, hx0:hx1]), skin(fc["normal"])
        if rs is not None and fs is not None:
            gain = rs / np.maximum(fs, 1)
            for k in ("ouch", "dizzy", "roar"):
                f = fc[k].astype(np.float32)
                lum = f[..., :3].mean(-1, keepdims=True)
                w = np.clip((lum - 45) / 60, 0, 1)        # 외곽선·검은 머리는 그대로
                f[..., :3] = np.clip(f[..., :3] * (1 + (gain - 1) * w), 0, 255)
                fc[k] = f.astype(np.uint8)
    for k in ("ouch", "dizzy", "roar"):
        h, x, y = fit_head(fc[k], cfg["head"], cfg.get("head_scale", 1.03))
        cover = np.zeros(body.shape[:2], bool)
        x, y = int(round(x)), int(round(y))
        cover[y:y + h.shape[0], x:x + h.shape[1]] = h[..., 3] > 60
        cover = ndimage.binary_dilation(cover, iterations=3)
        zone = np.zeros_like(cover)
        if cfg.get("erase"):
            er = cfg["erase"]
            for ex0, ey0, ex1, ey1 in (er if isinstance(er[0], (tuple, list)) else [er]):
                zone[ey0:ey1, ex0:ex1] = True
        else:
            zone[hy0:hy1 + 10, (hx0 + hx1) // 2:hx1 + 60] = True
            zone[max(0, hy0 - 20):hy0 + (hy1 - hy0) // 3, hx0 + (hx1 - hx0) // 4:hx1 + 60] = True   # 금관·귀 위쪽
        if cfg.get("erase_gold"):
            g = body.astype(int)
            gold = (g[..., 3] > 0) & (g[..., 0] > 150) & (g[..., 1] > 100) & (g[..., 2] < 120) & (g[..., 0] - g[..., 2] > 80)
            gold = ndimage.binary_dilation(ndimage.binary_closing(gold, iterations=3), iterations=6)
            gz = np.zeros_like(zone)
            gz[hy0 - 40:hy1, hx0:hx1 + 40] = True
            zone |= gold & gz
        b = body.copy()
        b[..., 3] = np.where(zone & ~cover, 0, b[..., 3])
        bodies[k] = paste(b, h, x, y)
    if cfg.get("anchor"):
        anchor = cfg["anchor"]
        feet = anchor[1]
    else:
        feet = max(l["bottom"] for l in legs)
        cxs = [l["cx"] for l in legs]
        anchor = ((min(cxs) + max(cxs)) / 2, feet)
    # 크기: 일반은 전신이 프레임 안, 구미호는 몸통 폭 기준(꼬리는 넘침)
    fw, fh = cfg.get("frame", FRAME[cfg["boss"]])
    allm = (body[..., 3] > 0) | (tail["img"][..., 3] > 0)
    for l in legs:
        allm |= l["img"][..., 3] > 0
    ys, xs = np.where(allm)
    if cfg.get("body_width"):
        s = fw * 2 * 0.98 / cfg["body_width"]
    else:
        s = min(fw * 2 / (xs.max() - xs.min() + 1), fh * 2 / (feet - ys.min() + 1))
    if cfg["base"] == "assemble":
        arms = []
    for a in arms:
        allm |= a["img"][..., 3] > 0
    return dict(bodies=bodies, legs=legs, arms=arms, tail=tail, anchor=anchor, scale=s, cfg=cfg,
                orbit=orbit if cfg["base"] != "assemble" else [])


def rot_layer(img, pivot, deg):
    if abs(deg) < 1e-3:
        return Image.fromarray(img, "RGBA")
    return Image.fromarray(img, "RGBA").rotate(deg, resample=Image.BICUBIC, center=pivot)


def pose(rig, t, face="normal", swing=None, tail_amp=None, bob=0.0, tilt=0.0):
    """t: 걷기 주기 0~1. 원본 좌표 큰 캔버스 RGBA 이미지."""
    cfg = rig["cfg"]
    A = cfg["swing"] if swing is None else swing
    fox = bool(cfg.get("tail")) and cfg["tail"][0] == "outside" and cfg["base"] != "assemble"
    TA = (4 if fox else 9) if tail_amp is None else tail_amp
    W = rig["bodies"]["normal"].shape[1]
    canvas = Image.new("RGBA", (W, W))
    tail_deg = TA * math.sin(2 * math.pi * (t - 0.18))
    lift = -bob
    order = [l for l in rig["legs"] if l["side"] == "far"]
    fl = int(round(lift)) if cfg.get("float") else 0
    canvas.alpha_composite(rot_layer(rig["tail"]["img"], rig["tail"]["pivot"], tail_deg), (0, fl))
    if "flame" in rig["tail"]:
        # 여우불: 꼬리를 따라가되 더 빠르게 일렁이고 밝기가 숨 쉬듯 바뀜
        f = rot_layer(rig["tail"]["flame"], rig["tail"]["pivot"], tail_deg + 2.2 * math.sin(2 * math.pi * 2 * t))
        a = np.asarray(f).astype(np.float32)
        a[..., 3] *= 0.82 + 0.18 * (0.5 + 0.5 * math.sin(2 * math.pi * 3 * t + 1))
        canvas.alpha_composite(Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA"), (0, int(round(-3 * abs(math.sin(2 * math.pi * 2 * t))))))
    for l in order:
        canvas.alpha_composite(rot_layer(l["img"], l["pivot"], A * math.sin(2 * math.pi * (t + l["phase"]))))
    body = Image.fromarray(rig["bodies"][face], "RGBA")
    if tilt:
        body = body.rotate(tilt, resample=Image.BICUBIC, center=rig["anchor"])
    near = [l for l in rig["legs"] if l["side"] == "near"]
    if cfg.get("legs_behind"):
        for l in near:
            canvas.alpha_composite(rot_layer(l["img"], l["pivot"], A * math.sin(2 * math.pi * (t + l["phase"]))))
    canvas.alpha_composite(body, (0, int(round(lift))))
    if not cfg.get("legs_behind"):
        for l in near:
            canvas.alpha_composite(rot_layer(l["img"], l["pivot"], A * math.sin(2 * math.pi * (t + l["phase"]))))
    AA = cfg.get("arm_swing", 0) if swing is None else swing * 0.6
    for a in rig.get("arms", []):
        canvas.alpha_composite(rot_layer(a["img"], a["pivot"], AA * math.sin(2 * math.pi * (t + a["phase"]))),
                               (0, int(round(lift))))
    for i, o in enumerate(rig.get("orbit", [])):
        dy = 14 * math.sin(2 * math.pi * (t + i / 3))
        canvas.alpha_composite(Image.fromarray(o, "RGBA"), (0, int(round(dy + lift * 0.4))))
    return canvas


def star_layer(size, center, n=3, r=20, phase=0.0):
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    cx, cy = center
    for i in range(n):
        a = 2 * math.pi * (i / n + phase)
        x, y = cx + math.cos(a) * r * 2.4, cy + math.sin(a) * r * 0.8
        pts = []
        for k in range(10):
            rr = r if k % 2 == 0 else r * 0.45
            aa = -math.pi / 2 + k * math.pi / 5
            pts.append((x + math.cos(aa) * rr, y + math.sin(aa) * rr))
        d.polygon(pts, fill=(255, 214, 74, 255), outline=OUTLINE + (255,), width=max(2, r // 6))
    return im


def puff_layer(size, center, rad, alpha):
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    cx, cy = center
    rng = np.random.default_rng(7)
    for i in range(7):
        a = 2 * math.pi * i / 7
        x, y = cx + math.cos(a) * rad * 0.7, cy + math.sin(a) * rad * 0.35
        rr = rad * (0.45 + 0.15 * rng.random())
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(236, 232, 224, int(255 * alpha)),
                  outline=(120, 110, 100, int(255 * alpha)), width=max(1, int(rad / 18)))
    return im


def finalize(img, rig, sx=1.0, sy=1.0, rot=0.0, dy=0.0, alpha=1.0, white=0.0):
    """원본 좌표 이미지 → 앵커 기준 변형 → 최종 배율로 축소. (이미지, 앵커 위치) 반환."""
    ax, ay = rig["anchor"]
    s = rig["scale"]
    if rot:
        img = img.rotate(rot, resample=Image.BICUBIC, center=(ax, ay))
    W, H = img.size
    nw, nh = max(1, round(W * s * sx)), max(1, round(H * s * sy))
    small = img.resize((nw, nh), Image.LANCZOS)
    a = np.asarray(small).astype(np.float32)
    if white:
        a[..., :3] = a[..., :3] * (1 - white) + 255 * white
    if alpha < 1:
        a[..., 3] *= alpha
    small = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
    return small, (ax * s * sx, ay * s * sy + dy)


def render_set(rig):
    cfg = rig["cfg"]
    boss = cfg["boss"]
    W = rig["bodies"]["normal"].shape[1]
    ax, ay = rig["anchor"]
    head = cfg["head"]
    sets = {}
    # 걷기 6 (10fps): 네발 대각선 다리 + 몸 들썩임 (한 주기에 두 번)
    walk = []
    for i in range(6):
        t = i / 6
        if cfg.get("float"):
            bob = 22 * (0.5 - 0.5 * math.cos(2 * math.pi * t))
            tilt = 2.0 * math.sin(2 * math.pi * t)
        else:
            bob = 10 * (0.5 - 0.5 * math.cos(4 * math.pi * t))
            tilt = 1.2 * math.sin(2 * math.pi * t)
        walk.append((finalize(pose(rig, t, bob=bob, tilt=tilt), rig), 100))
    sets["walk"] = walk
    # 피격 1: 아야 얼굴 + 하얀 번쩍임 + 살짝 눌림
    sets["hit"] = [(finalize(pose(rig, 0, face="ouch", swing=0), rig, sx=1.04, sy=0.96, white=0.45), 120)]
    # 쓰러짐 (일반 4 · 보스 6): 어지러운 눈 → 휘청 → 납작 → 연기
    n = 6 if boss else 4
    die = []
    for i in range(n):
        p = i / (n - 1)
        img = pose(rig, 0, face="dizzy", swing=0, tail_amp=0)
        stars = star_layer((W, W), ((head[0] + head[2]) / 2, head[1] - 10), r=26, phase=p * 0.6)
        if p < 0.75:
            img.alpha_composite(stars)
        rot = [-6, 8, -14, -14, -14, -14][min(i, 5)] if boss else [-6, 10, -14, -14][i]
        sy = 1 - 0.35 * max(0, p - 0.3) / 0.7
        sx = 1 + 0.12 * max(0, p - 0.3) / 0.7
        al = 1 if p < 0.5 else 1 - (p - 0.5) / 0.5 * 0.85
        fr, anc = finalize(img, rig, sx=sx, sy=sy, rot=rot, alpha=al)
        if p >= 0.5:
            # 연기: 몸 한가운데에서 피어오름 (출력 배율로 바로 그림)
            bb = fr.getbbox()
            pad = 30
            canvas = Image.new("RGBA", (fr.width + pad * 2, fr.height + pad * 2))
            canvas.alpha_composite(fr, (pad, pad))
            rad = (110 + 190 * p) * rig["scale"]
            cx = pad + (bb[0] + bb[2]) / 2
            cy = pad + bb[1] + (bb[3] - bb[1]) * 0.55
            canvas.alpha_composite(puff_layer(canvas.size, (cx, cy), rad, min(1, 1.6 - p)))
            fr, anc = canvas, (anc[0] + pad, anc[1] + pad)
        die.append(((fr, anc), 100))
    sets["die"] = die
    # 보스 등장 6 (12fps): 위에서 떨어져 착지 → 포효
    if boss:
        app = []
        steps = [dict(dy=-0.55, sx=.9, sy=1.12, al=.5, face="normal"),
                 dict(dy=-0.18, sx=.94, sy=1.08, al=1, face="normal"),
                 dict(dy=0, sx=1.14, sy=.84, al=1, face="roar", dust=.9),
                 dict(dy=0, sx=.97, sy=1.05, al=1, face="roar", dust=.6),
                 dict(dy=0, sx=1.0, sy=1.0, al=1, face="roar", dust=.3),
                 dict(dy=0, sx=1.0, sy=1.0, al=1, face="normal")]
        H = (ay - min(np.where(rig["bodies"]["normal"][..., 3] > 0)[0])) * rig["scale"]
        for st in steps:
            img = pose(rig, 0, face=st["face"], swing=0)
            fr, anc = finalize(img, rig, sx=st["sx"], sy=st["sy"], alpha=st["al"], dy=-st["dy"] * H)
            if st.get("dust"):
                d = st["dust"]
                c = Image.new("RGBA", (fr.width + 80, fr.height + 40))
                c.alpha_composite(fr, (40, 20))
                anc = (anc[0] + 40, anc[1] + 20)
                for side in (-1, 1):
                    pl = puff_layer((W, W), (ax + side * 260, ay - 30), 90 * (1.4 - d * 0.4), d)
                    pf, _ = finalize(pl, rig)
                    c.alpha_composite(pf, (round(anc[0] - ax * rig["scale"]), round(anc[1] - ay * rig["scale"])))
                fr = c
            app.append(((fr, anc), 83))
        sets["appear"] = app
    return sets


def write_sheet(name, anim, frames, fps):
    """프레임마다 앵커가 같은 자리에 오도록 공통 캔버스에 놓고 가로 시트로."""
    left = max(a[0] for (im, a), _ in frames)
    right = max(im.width - a[0] for (im, a), _ in frames)
    top = max(a[1] for (im, a), _ in frames)
    bottom = max(im.height - a[1] for (im, a), _ in frames)
    cells = []
    for (im, a), dur in frames:
        c = Image.new("RGBA", (math.ceil(left + right), math.ceil(top + bottom)))
        c.alpha_composite(im, (round(left - a[0]), round(top - a[1])))
        cells.append((c, dur))
    # 투명 여백 정리
    union = None
    for c, _ in cells:
        bb = c.getbbox()
        if bb:
            union = bb if union is None else (min(union[0], bb[0]), min(union[1], bb[1]), max(union[2], bb[2]), max(union[3], bb[3]))
    x0, y0 = max(0, union[0] - 2), max(0, union[1] - 2)
    x1, y1 = union[2] + 2, union[3] + 2
    cells = [(c.crop((x0, y0, x1, y1)), d) for c, d in cells]
    fw, fh = x1 - x0, y1 - y0
    axr, ayr = (left - x0) / fw, (top - y0) / fh
    tag = f"{name}-{anim}" if anim else name
    sheet = Image.new("RGBA", (fw * len(cells), fh))
    meta = {"frames": {}, "animations": {}, "meta": {}}
    keys = []
    for i, (c, d) in enumerate(cells):
        sheet.alpha_composite(c, (i * fw, 0))
        k = f"{tag}-{i}" if anim else tag
        keys.append(k)
        meta["frames"][k] = {"frame": {"x": i * fw, "y": 0, "w": fw, "h": fh}, "duration": d,
                             "anchor": {"x": round(axr, 4), "y": round(ayr, 4)}}
    return sheet, meta, keys, cells


def build(name):
    cfg = MONSTERS[name]
    print("build", name)
    rig = build_rig(name, cfg)
    sets = render_set(rig)
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    os.makedirs(PREV, exist_ok=True)
    fw, fh = cfg.get("frame", FRAME[cfg["boss"]])
    fps = {"walk": 10, "hit": 10, "die": 10, "appear": 12}
    previews = {}
    for anim, frames in sets.items():
        sheet, meta, keys, cells = write_sheet(name, anim, frames, fps[anim])
        meta["animations"][anim] = keys
        meta["meta"] = {"image": f"{name}-{anim}.png", "size": {"w": sheet.width, "h": sheet.height},
                        "scale": "2", "fps": fps[anim], "loop": anim == "walk",
                        "body": {"w": fw, "h": fh},
                        "note": "anchor = 발밑(앞뒤 발 가운데). body = 판정용 보드 크기(px). 좌우 반전 시 x' = w - x"}
        sheet.save(os.path.join(d, f"{name}-{anim}.png"), optimize=True)
        json.dump(meta, open(os.path.join(d, f"{name}-{anim}.json"), "w"), ensure_ascii=False, indent=1)
        previews[anim] = cells
    # 정지 그림 (걷기 0번)
    sheet, meta, keys, cells = write_sheet(name, None, [sets["walk"][0]], 1)
    cells[0][0].save(os.path.join(d, f"{name}.png"), optimize=True)
    # 미리보기 GIF (풀밭 위 2배 확대)
    for anim, cells in previews.items():
        frames = []
        for c, dur in cells:
            bg = Image.new("RGBA", c.size, (0xB9, 0xC5, 0x9E, 255))
            bg.alpha_composite(c)
            frames.append((bg.resize((c.width * 2, c.height * 2), Image.NEAREST).convert("P", palette=Image.ADAPTIVE), dur))
        frames[0][0].save(os.path.join(PREV, f"{name}-{anim}.gif"), save_all=True,
                          append_images=[f for f, _ in frames[1:]], duration=[d for _, d in frames],
                          loop=0 if anim == "walk" else 0, disposal=2)
    return rig


if __name__ == "__main__":
    names = sys.argv[1:] or list(MONSTERS)
    for n in names:
        build(n)
