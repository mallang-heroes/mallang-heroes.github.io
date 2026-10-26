"""제미나이 단색 배경 제거·조각 분리 공통 함수."""
import numpy as np
from PIL import Image
from scipy import ndimage


def key_out(path, key="magenta", drop_shadow=False):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    if key == "magenta":
        m = np.minimum(r, b) - g
        K = np.array([252.0, 45.0, 253.0])
        alpha = np.clip((180.0 - m) / (180.0 - 60.0), 0, 1)
        # 워터마크 반짝이처럼 밝아진 마젠타(분홍빛 흰색)도 배경으로
        alpha[(r > 225) & (b > 215) & (g < 135) & (np.abs(r - b) < 30)] = 0
        if drop_shadow:   # 제미나이가 발밑에 그린 보랏빛 그림자 (게임에서 따로 그림)
            alpha[(r - g > 60) & (b - g > 60) & (np.abs(r - b) < 45) & (g < 120)] = 0
    else:  # green
        m = g - np.maximum(r, b)
        K = np.array([10.0, 245.0, 20.0])
        alpha = np.clip((170.0 - m) / (170.0 - 50.0), 0, 1)
    h, w = alpha.shape
    # 제미나이 워터마크(오른쪽 아래 반짝이)
    y0, y1, x0, x1 = int(h*.79), int(h*.93), int(w*.87), int(w*.955)
    wm = alpha[y0:y1, x0:x1]
    lab, n = ndimage.label(wm > .05)
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(ys) < 3000 and (ys.max() - ys.min()) < 70 and (xs.max() - xs.min()) < 70:
            wm[lab == i] = 0
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - alpha)[..., None] * K) / safe, 0, 255)
    edge = (alpha > 0) & (alpha < .98)
    if key == "magenta":
        lim = rgb[..., 1] + 55
        for c in (0, 2):
            rgb[..., c] = np.where(edge, np.minimum(rgb[..., c], np.maximum(lim, rgb[..., c]*.8)), rgb[..., c])
    else:
        lim = np.maximum(rgb[..., 0], rgb[..., 2]) + 25
        rgb[..., 1] = np.where(edge, np.minimum(rgb[..., 1], lim), rgb[..., 1])
    return Image.fromarray(np.dstack([rgb, alpha*255]).astype(np.uint8), "RGBA")


def components(img, merge=6, min_area=400):
    """merge px 이내로 붙은 조각은 한 덩어리로. (bbox, 잘린 이미지) 목록."""
    a = np.asarray(img)
    solid = a[..., 3] > 30
    grown = ndimage.binary_dilation(solid, iterations=merge) if merge else solid
    lab, n = ndimage.label(grown, structure=np.ones((3, 3)))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        own = (lab[sl] == i) & solid[sl]
        if own.sum() < min_area:
            continue
        crop = a[sl].copy()
        crop[..., 3] = np.where(ndimage.binary_dilation(own, iterations=2), crop[..., 3], 0)
        im = Image.fromarray(crop, "RGBA")
        bb = im.getbbox()
        out.append(((sl[1].start + bb[0], sl[0].start + bb[1], sl[1].start + bb[2], sl[0].start + bb[3]), im.crop(bb), int(own.sum())))
    return out
