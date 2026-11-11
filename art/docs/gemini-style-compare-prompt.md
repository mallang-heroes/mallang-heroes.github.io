# 제미나이 프롬프트 — 그림체 비교 (잔 도트 vs 카툰)

> 2026-11-11. 맵 도트(1도트 = 보드 3)에 유닛을 맞추면 유닛, 특히 위인 퀄리티가 너무 떨어진다.
> 그래서 **맵 쪽을 바꾸는** 두 방향을 같은 배치로 뽑아 나란히 비교한다.
> - A. 잔 도트("HD 도트", 1도트 = 보드 1.5~2): 도트 느낌은 살리고 유닛 디테일을 확보
> - B. 부드러운 카툰 (도트 없음): 제미나이가 가장 잘 그리고, 크기 조절·회전 모션이 자유로움

## 쓰는 법
1. A와 B는 **각각 새 대화**에서 뽑는다 (한 대화에서 이어 하면 앞 그림체가 섞임).
2. 첨부 2장 (둘 다 같음):
   - `art/preview/map-portrait/bg.png`: 지금 맵. 길·칸 배치를 똑같이 따라 그리게 하는 기준
   - `art/source/gemini/slime-base/spear-sheet.png`: 창병 슬라임 4등급. 디자인 기준
3. 영어 블록만 복사해서 붙여 넣는다.
4. 결과 2장을 Claude에게 넘기고 **"그림체 비교해줘"** 라고 하면 된다.
   Claude가 하는 일: 지금 맵과 같은 크기로 맞춤 → 지금 굵은 도트 시안과 셋을 나란히 붙임 → 휴대폰 실제 크기 미리보기.

## A. 잔 도트 (HD 도트)
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The first attached image is the vertical map of my cute mobile tower-defense game. The second image shows my unit design: a red jelly slime spear soldier in 4 ranks (recruit, soldier, officer, general).
Redraw the whole map as a finer, more detailed pixel-art scene, like a modern high-resolution pixel-art mobile game: pixels about HALF the size of the pixels in the attached map, crisp square pixels, no anti-aliasing, no blur, limited flat palette, a 1-pixel dark slate outline (#3C4446) around objects, light from the top-left.
Keep the layout EXACTLY the same: the same portrait size and proportions, the dirt road in the same S-shaped path and width, the grass areas in the same places, the royal palace at the top in the same place and size, the boulder cave entrance at the bottom right in the same place and size. Same cheerful, slightly muted palette (olive grass, warm sand road, grey-blue stones).
Put 8 slime units standing on the grass areas beside the road, in rows, mixing the 4 ranks of the attached spear soldier design, drawn in the same fine pixel style as the new map, each with a small shadow. Biggest (general) about as wide as one quarter of the palace. Cute readable faces: two dark eyes with a white shine, pink cheeks, a small smile.
Also put 4 small round brown blob monsters walking on the road.
No UI, no buttons, no frame.
```

## B. 부드러운 카툰
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The first attached image is the vertical map of my cute mobile tower-defense game. The second image shows my unit design: a red jelly slime spear soldier in 4 ranks (recruit, soldier, officer, general).
Redraw the whole map in a clean, cute, smooth 2D cartoon style (NOT pixel art), like a polished casual mobile game: smooth shapes, soft clean shading, gentle highlights, a thin dark outline around objects, light from the top-left.
Keep the layout EXACTLY the same: the same portrait size and proportions, the dirt road in the same S-shaped path and width, the grass areas in the same places, the royal palace at the top in the same place and size (Korean Joseon palace gate with a curved tiled roof), the boulder cave entrance at the bottom right in the same place and size. Same cheerful palette (fresh green grass, warm sand road, grey-blue stones).
Put 8 slime units standing on the grass areas beside the road, in rows, mixing the 4 ranks of the attached spear soldier design, redrawn in the same smooth cartoon style as the new map, glossy jelly bodies, each with a soft shadow. Biggest (general) about as wide as one quarter of the palace. Cute readable faces: two big dark eyes with white shines, pink cheeks, a small smile.
Also put 4 small round brown blob monsters walking on the road.
No UI, no buttons, no frame.
```

## 다시 뽑을 때 덧붙일 말
| 문제 | 덧붙일 영어 |
|---|---|
| 길·궁 위치가 바뀜 | `Follow the attached map layout exactly: same road path, same palace and cave positions, only change the drawing style.` |
| A가 굵은 도트로 나옴 | `Smaller pixels: about half the pixel size of the attached map, more detail.` |
| A가 부드러운 그림처럼 나옴 | `Strict pixel art: hard square pixels only, no gradients, no soft painting.` |
| B가 도트처럼 나옴 | `No pixels at all, smooth vector-like cartoon shapes.` |
| 슬라임이 너무 큼 | `Make the slimes smaller, they must fit on the grass between the roads.` |
