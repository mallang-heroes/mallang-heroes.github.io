"""저장소 그림 → 유니티 프로젝트(unity/Assets/Resources/Art)로 복사.

유니티는 webp를 못 읽으므로 PNG로 바꿔 넣는다. 그림을 새로 만든 뒤 이 스크립트만 다시 돌리면 된다.
  Map/ground.png        궁·동굴 뺀 바닥 (@2x, 1170×1668)
  Map/palace.png        궁 (투명, @2x)
  Map/cave-glow.png     동굴 4프레임 시트 (@2x)
  Units/<병과>-<등급>.png  도트 슬라임 (1도트 = 4px로 키움)
  UnitsV2/<병과>-<등급>.png  유니티 시트로 다시 뽑은 큰 슬라임 (1도트 = 3px)
  UnitsB/<병과|base>-<등급>.png  맵에 맞춘 기본 슬라임·장비 (1도트 = 3px, 게임 크기는 몸 폭으로 맞춤)
  Map/layout.json       궁·동굴 위치, 동굴 프레임, 배치 칸, 슬라임 발 위치 (유니티 JsonUtility용, 게임 코드는 이것만 읽음)
실행: python3 art/tools/unity/sync_art.py (저장소 루트에서)
"""
import json
import os
import shutil

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
DST = os.path.join(ROOT, 'unity/Assets/Resources/Art')
UNIT_PX = 4   # 도트 유닛 1도트 = 4px (Sprites.cs UnitPxPerDot과 같아야 함)
UNIT2_PX = 3  # 큰 새 유닛(UnitsV2) 1도트 = 3px (보드 1.5) — Sprites.cs Unit2PxPerDot


def png(src, dst):
    Image.open(os.path.join(ROOT, src)).save(os.path.join(DST, dst))


def main():
    os.makedirs(os.path.join(DST, 'Map'), exist_ok=True)
    os.makedirs(os.path.join(DST, 'Units'), exist_ok=True)
    png('assets/images/map/map-portrait-ground.webp', 'Map/ground.png')
    png('assets/images/map/map-portrait-palace.webp', 'Map/palace.png')
    png('assets/images/map/map-portrait-cave-glow.webp', 'Map/cave-glow.png')
    dots = os.path.join(ROOT, 'art/source/gemini/slime-pixel/dots')
    for f in sorted(os.listdir(dots)):
        if not f.endswith('.png'): continue
        # 1도트 = 4px로 미리 키워 둔다 (폰 1170 폭에서 1도트 = 화면 4px로 딱 맞고,
        # 다른 크기 화면에서도 부드럽게 줄여져 도트 굵기가 들쭉날쭉하지 않음)
        im = Image.open(os.path.join(dots, f))
        im.resize((im.width * UNIT_PX, im.height * UNIT_PX), Image.NEAREST).save(os.path.join(DST, 'Units', f))
    # 큰 새 유닛 (유니티 시트로 다시 뽑은 것)
    dots2 = os.path.join(ROOT, 'art/source/gemini/slime-unity/dots')
    feet2 = {}
    if os.path.isdir(dots2):
        os.makedirs(os.path.join(DST, 'UnitsV2'), exist_ok=True)
        for f in sorted(os.listdir(dots2)):
            if not f.endswith('.png'): continue
            im = Image.open(os.path.join(dots2, f))
            im.resize((im.width * UNIT2_PX, im.height * UNIT2_PX), Image.NEAREST).save(os.path.join(DST, 'UnitsV2', f))
        feet2 = json.load(open(os.path.join(dots2, 'feet.json'), encoding='utf-8'))
    # 맵에 맞춘 기본 슬라임 + 장비 (UnitsB): 몸 폭으로 게임 크기를 맞추므로 발 위치와 함께 몸 폭도 넘긴다
    dotsb = os.path.join(ROOT, 'art/source/gemini/slime-base/dots')
    feetb = {}
    if os.path.isdir(dotsb):
        os.makedirs(os.path.join(DST, 'UnitsB'), exist_ok=True)
        for f in sorted(os.listdir(dotsb)):
            if not f.endswith('.png'): continue
            im = Image.open(os.path.join(dotsb, f))
            im.resize((im.width * UNIT2_PX, im.height * UNIT2_PX), Image.NEAREST).save(os.path.join(DST, 'UnitsB', f))
        feetb = json.load(open(os.path.join(dotsb, 'feet.json'), encoding='utf-8'))
    # 유니티 JsonUtility로 읽기 쉬운 모양(사전 없이 목록만)으로 한 파일에 모음
    m = json.load(open(os.path.join(ROOT, 'assets/data/map-portrait.json'), encoding='utf-8'))
    glow = json.load(open(os.path.join(ROOT, 'assets/images/map/map-portrait-cave-glow.json'), encoding='utf-8'))
    feet = json.load(open(os.path.join(dots, 'feet.json'), encoding='utf-8'))
    frames = [v['frame'] for _, v in sorted(glow['frames'].items())]
    layout = {
        'boardW': m['board'][0], 'boardH': m['board'][1], 'tile': m['tile'],
        'tiles': [{'x': t[0], 'y': t[1]} for t in m['tiles']],
        'palace': m['palace']['rect'],
        'cave': m['cave']['rect'],
        'caveMouth': {'x': m['cave']['mouth'][0], 'y': m['cave']['mouth'][1]},
        'caveFrames': frames,
        'caveFrameMs': list(glow['frames'].values())[0]['duration'],
        'feet': [{'name': k, 'x': v[0], 'y': v[1]} for k, v in sorted(feet.items())],
        'feetV2': [{'name': k, 'x': v[0], 'y': v[1]} for k, v in sorted(feet2.items()) if not k.startswith('base-')],
        'feetB': [{'name': k, 'x': v[0], 'y': v[1], 'w': v[2]} for k, v in sorted(feetb.items())],
    }
    json.dump(layout, open(os.path.join(DST, 'Map/layout.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('ok', sorted(os.listdir(os.path.join(DST, 'Units'))))


if __name__ == '__main__':
    main()
