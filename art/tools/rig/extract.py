#!/usr/bin/env python3
"""제미나이 소스(단색 마젠타 배경)에서 배경을 지우고 파츠를 하나씩 잘라 낸다.

사용: python3 extract.py src/<이름>-parts.png [src/<이름>-ref.png]
결과: parts/<이름>/part-XX.png (+ ref.png), parts/<이름>/index.png (번호 붙인 확인용)
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

KEY = np.array([255.0, 0.0, 255.0])


def key_out(path):
    """마젠타 배경 → 투명. 경계 픽셀은 배경색을 빼서 색 번짐(despill)을 없앤다."""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.minimum(r, b) - g                   # 마젠타 정도 (배경 ≈ 240)
    alpha = np.clip((215.0 - m) / (215.0 - 70.0), 0, 1)
    # 제미나이 워터마크(오른쪽 아래 반짝이) 지우기
    h, w = alpha.shape
    alpha[int(h*.80):int(h*.92), int(w*.88):int(w*.95)] *= (m[int(h*.80):int(h*.92), int(w*.88):int(w*.95)] < 120)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = (a - (1 - alpha)[..., None] * KEY) / safe
    rgb = np.clip(rgb, 0, 255)
    # 남은 분홍 테두리 억제: 반투명 픽셀에서 R·B가 G보다 과하게 크면 낮춤
    edge = (alpha > 0) & (alpha < .98)
    lim = rgb[..., 1] + 60
    rgb[..., 0] = np.where(edge, np.minimum(rgb[..., 0], np.maximum(lim, rgb[..., 0] * .85)), rgb[..., 0])
    rgb[..., 2] = np.where(edge, np.minimum(rgb[..., 2], np.maximum(lim, rgb[..., 2] * .85)), rgb[..., 2])
    out = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def split(img, min_area=1500):
    al = np.asarray(img)[..., 3]
    lab, n = ndimage.label(al > 20, structure=np.ones((3, 3)))
    parts = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        area = int((lab[sl] == i).sum())
        if area < min_area:
            continue
        crop = np.asarray(img)[sl].copy()
        crop[..., 3] = np.where(lab[sl] == i, crop[..., 3], 0)
        # 경계의 반투명 픽셀도 포함 (라벨 주변 2px 확장)
        grown = ndimage.binary_dilation(lab[sl] == i, iterations=2)
        crop[..., 3] = np.where(grown, np.asarray(img)[sl][..., 3], 0)
        parts.append(((sl[1].start, sl[0].start), Image.fromarray(crop, "RGBA"), area))
    parts.sort(key=lambda p: (p[0][1] // 120, p[0][0]))
    return parts


if __name__ == "__main__":
    src = sys.argv[1]
    name = os.path.basename(src).replace("-parts.png", "")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "parts", name)
    os.makedirs(out, exist_ok=True)
    img = key_out(src)
    img.save(os.path.join(out, "parts-keyed.png"))
    parts = split(img)
    idx = Image.new("RGBA", img.size, (90, 140, 90, 255))
    d = ImageDraw.Draw(idx)
    for k, ((x, y), p, area) in enumerate(parts):
        p.save(os.path.join(out, f"part-{k:02d}.png"))
        idx.alpha_composite(p, (x, y))
        d.rectangle((x, y, x + p.width, y + p.height), outline=(255, 255, 0, 255), width=2)
        d.text((x + 6, y + 4), str(k), fill=(255, 255, 0, 255), font=ImageFont.load_default(size=36))
        print(k, (x, y), p.size, area)
    idx.save(os.path.join(out, "index.png"))
    if len(sys.argv) > 2:
        ref = key_out(sys.argv[2])
        ref = ref.crop(ref.getbbox())
        ref.save(os.path.join(out, "ref.png"))
        print("ref", ref.size)
