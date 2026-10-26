"""라인업·포즈 그림에서 캐릭터를 한 마리씩 분리 (붙어 있으면 얇은 연결부를 끊어 가장 가까운 쪽으로 배정)."""
import numpy as np
from PIL import Image
from scipy import ndimage


def split_characters(img, expect, min_area=3000):
    a = np.asarray(img)
    solid = a[..., 3] > 30
    for it in range(0, 12):
        core = ndimage.binary_erosion(solid, iterations=it) if it else solid
        lab, n = ndimage.label(core, structure=np.ones((3, 3)))
        sizes = ndimage.sum(core, lab, range(1, n + 1))
        big = [i + 1 for i, s in enumerate(sizes) if s >= min_area]
        if len(big) >= expect:
            break
    big = sorted(big, key=lambda k: -sizes[k - 1])[:expect]
    seeds = np.zeros(solid.shape, np.int32)
    for j, k in enumerate(big, 1):
        seeds[lab == k] = j
    # 모든 불투명 픽셀을 가장 가까운 씨앗에 배정
    _, (iy, ix) = ndimage.distance_transform_edt(seeds == 0, return_indices=True)
    owner = seeds[iy, ix]
    out = []
    for j in range(1, expect + 1):
        m = (owner == j) & (a[..., 3] > 0)
        crop = a.copy()
        crop[..., 3] = np.where(m, a[..., 3], 0)
        im = Image.fromarray(crop, "RGBA")
        bb = im.getbbox()
        out.append((bb, im.crop(bb)))
    out.sort(key=lambda t: t[0][0])
    return out
