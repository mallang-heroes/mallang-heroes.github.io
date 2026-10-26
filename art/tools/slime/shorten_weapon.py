"""총통 같은 긴 무기의 가운데 쇠 부분을 잘라 내고 총구를 뒤로 당겨 길이를 줄인다.
python3 shorten_weapon.py <src.png> <dst.png> <몸 오른쪽 끝 x> [쇠 부분 중 잘라 낼 비율]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
from keying import key_out

src, dst, xb = sys.argv[1], sys.argv[2], int(sys.argv[3])
frac = float(sys.argv[4]) if len(sys.argv) > 4 else .6
abs_cut = float(sys.argv[5]) if len(sys.argv) > 5 else None
im = key_out(src)
a = np.asarray(im).astype(np.float32)
al = a[..., 3]
H, W = al.shape
yy, xx = np.mgrid[0:H, 0:W]
wpn = (al > 30) & (xx > xb)
lab, n = ndimage.label(wpn)
sizes = ndimage.sum(wpn, lab, range(1, n + 1))
wpn = lab == (int(np.argmax(sizes)) + 1)
ys, xs = np.where(wpn)
# 무기 축 방향 (주성분)
P = np.c_[xs, ys].astype(np.float64)
c = P.mean(0)
u = np.linalg.svd(P - c, full_matrices=False)[2][0]
if u[0] < 0:
    u = -u
t_all = (np.c_[xx.ravel(), yy.ravel()] - c) @ u
t_all = t_all.reshape(H, W)
# 회색 쇠 부분의 축 위치 범위
r, g, b = a[..., 0], a[..., 1], a[..., 2]
mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
steel = wpn & (mx - mn < 45) & (mx > 70)
ts = t_all[steel]
lo, hi = np.percentile(ts, 8), np.percentile(ts, 92)
cut = abs_cut if abs_cut else (hi - lo) * frac
t1 = lo + max(0, (hi - lo - cut) / 2)
t2 = t1 + cut
# 결과: 무기 영역에서 t >= t1 인 부분은 지우고, t >= t2 였던 부분을 cut 만큼 뒤로 옮겨 붙임
out = a.copy()
region = wpn | (ndimage.binary_dilation(wpn, iterations=3) & (al > 0) & (xx > xb))
erase = region & (t_all >= t1)
out[erase, 3] = 0
moved = np.zeros_like(a)
keep = region & (t_all >= t2)
src_part = np.where(keep[..., None], a, 0)
shift = -u * cut
moved = ndimage.shift(src_part, (shift[1], shift[0], 0), order=1, mode="constant")
mimg = Image.fromarray(np.clip(moved, 0, 255).astype(np.uint8), "RGBA")
oimg = Image.fromarray(out.astype(np.uint8), "RGBA")
oimg.alpha_composite(mimg)
bg = Image.new("RGBA", oimg.size, (255, 0, 255, 255))
bg.alpha_composite(oimg)
bg.convert("RGB").save(dst)
print("axis", np.round(u, 3), "steel t", round(lo), round(hi), "cut", round(cut))
