"""게임 에셋 PNG → WebP 변환 (품질 90, 투명 배경 유지).

assets/images 아래 PNG를 모두 WebP로 바꾸고 PNG는 지운다.
같은 폴더의 시트 JSON(meta.image)도 .webp로 고친다. 여러 번 실행해도 된다.
그림 스크립트(슬라임·몬스터·맵)는 PNG로 내보내므로, 새 그림을 assets/images에 넣은 뒤 꼭 실행한다.
원본·미리보기(art/)는 PNG 그대로 둔다.
실행: python3 art/tools/web/to_webp.py  (저장소 루트에서)
"""
import glob, os, re
from PIL import Image

QUALITY = 90
n = 0
for png in sorted(glob.glob('assets/images/**/*.png', recursive=True)):
    webp = png[:-4] + '.webp'
    im = Image.open(png)
    im = im.convert('RGBA') if 'A' in im.getbands() or im.mode == 'P' else im.convert('RGB')
    im.save(webp, 'WEBP', quality=QUALITY, alpha_quality=100, method=6)
    os.remove(png)
    n += 1
fixed = 0
for js in glob.glob('assets/images/**/*.json', recursive=True):
    s = open(js, encoding='utf-8').read()
    t = re.sub(r'("image"\s*:\s*"[^"]*)\.png"', r'\1.webp"', s)   # 원래 서식은 그대로 두고 확장자만
    if t != s:
        open(js, 'w', encoding='utf-8').write(t)
        fixed += 1
print(f'WebP {n}장 변환, JSON {fixed}개 수정')
