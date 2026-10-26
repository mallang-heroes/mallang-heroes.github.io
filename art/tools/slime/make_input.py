"""라인업(A)에서 장수만 잘라 B1·B2용 입력 그림을 만든다: python3 make_input.py <branch>"""
import sys
from PIL import Image
from keying import key_out
from split_units import split_characters
from process_branch import clean_edges, remove_sparkle
b = sys.argv[1]
A = clean_edges(remove_sparkle(key_out(f"src2/{b}-A.png"), None))
units = split_characters(A, 4)
for (bb, im), n in zip(units, ["gunjol", "jeongbyeong", "gungwan", "jangsu"]):
    print(n, bb)
g = units[3][1]
W, H = 1376, 768
c = Image.new("RGBA", (W, H), (255, 0, 255, 255))
k = 520 / g.height
gi = g.resize((round(g.width*k), round(g.height*k)), Image.LANCZOS)
c.alpha_composite(gi, (260, (H - gi.height)//2 + 20))
c.convert("RGB").save(f"src2/{b}-jangsu-input.png")
c.convert("RGB").save(f"/home/claude/{b}-jangsu-input.png")
