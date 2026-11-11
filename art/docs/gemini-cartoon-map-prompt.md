# 제미나이 프롬프트 — 카툰 맵 새로 (B 그림체 확정)

> 2026-11-11. 그림체 비교(`gemini-style-compare-prompt.md`)에서 **B. 부드러운 카툰**으로 확정했다.
> 비교 결과 원본: `art/source/gemini/map-cartoon/style-ref-b.png` (확정), `style-ref-a-pixel.png` (잔 도트, 탈락).
> 이유: 게임 크기로 줄여도 깨지지 않고, 창 회전 같은 모션이 자연스럽고, 위인 디테일을 넣기 쉽다.
> 배경부터 새로 그린다. 제미나이가 길 모양을 매번 바꾸므로 **배치 가이드**를 같이 첨부한다.

## 준비물
- `art/source/gemini/map-cartoon/layout-guide.png`: 게임 규칙(`Board.cs MapData`) 그대로 칠한 배치 가이드. `python3 art/tools/map/make_layout_guide.py`로 만든다.
  - 모래색 띠 = 길 (폭 60, 동굴 → 3층 구불길 → 궁)
  - 회색 네모 = 궁 자리
  - 청회색 동그라미 = 동굴 자리
  - 맨 위 진회색 띠 = 담장
  - 초록 = 잔디. 유닛 배치 칸 25개(5줄 × 5칸)가 길 사이 잔디에 들어간다.
- `art/source/gemini/map-cartoon/style-ref-b.png`: 그림체 기준.

## 쓰는 법
1. 새 대화에서 첨부 2장(가이드 → 그림체 기준 순서)과 ① 영어 블록을 보낸다.
2. 맵이 마음에 들면 **같은 대화에서** ②로 궁, ③으로 동굴을 따로 받는다. 유닛이 궁·동굴 앞뒤로 겹쳐 그려지게 하려면 따로 있어야 한다.
3. 결과 3장을 Claude에게 넘기고 **"카툰 맵 넣어줘"** 라고 하면 된다.
   Claude가 하는 일: 맵을 보드 크기(@2x 1170×1668)로 맞춤 → 가이드와 길 위치가 맞는지 겹쳐 확인 → 궁·동굴 하늘색 지우고 자리 맞춤 → 유니티에 넣기.

## ① 빈 맵
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The first attached image is a flat color LAYOUT GUIDE for the vertical map of my cute mobile tower-defense game. The second attached image shows the ART STYLE I want.
Draw the finished map following the layout guide EXACTLY, in the art style of the second image (clean, cute, smooth 2D cartoon, NOT pixel art, soft clean shading, gentle highlights, a thin dark outline around objects, light from the top-left):
- the sand-colored band is a dirt road: keep its exact path, width and corners. It starts at the cave at the bottom right, zigzags up the map and ends at the palace.
- the grey rectangle is the royal palace: a Korean Joseon palace gate building with a curved blue-tiled roof on a stone platform with front steps, filling that rectangle.
- the blue-grey round shape at the bottom right is a monster cave: a cute mound of round grey-blue boulders with some moss and a small bush, a dark arched entrance on its left side where the road goes in, a straw rope with white paper strips across the entrance. Part of it may go off the right and bottom edges.
- the dark band at the top is a low traditional stone wall with a tiled top, behind the palace, with a few round trees in front of it.
- everything green is fresh grass: smooth and calm, only a few tiny grass tufts and small flowers near the edges, keep the big grass areas between the roads open and plain (units will stand there later).
The road has soft grassy edges. Same cheerful palette as the second image.
No units, no slimes, no monsters, no characters, no UI, no frame. Same portrait proportions as the layout guide, at the highest resolution you can.
```

## ② 궁만 (같은 대화)
```
Great. Now draw only the palace from this map again, exactly the same design, colors and size, including its stone platform and steps, on one solid flat cyan background (#00FFFF). Nothing else: no grass, no road, no wall, no trees, no shadow on the background.
```

## ③ 동굴만 (같은 대화)
```
Now draw only the cave from this map again, exactly the same design, colors and size, the whole cave fully visible (not cut off), on one solid flat cyan background (#00FFFF). Nothing else: no grass, no road, no shadow on the background.
```

## 다시 뽑을 때 덧붙일 말
| 문제 | 덧붙일 영어 |
|---|---|
| 길 모양·위치가 가이드와 다름 | `The road must follow the sand band of the layout guide exactly, same turns at the same places.` |
| 잔디에 장식이 너무 많음 | `Keep the grass between the roads plain and open, decorations only at the very edges.` |
| 도트처럼 나옴 | `Smooth cartoon shapes, no pixels.` |
| 궁이 너무 작거나 큼 | `The palace fills the grey rectangle of the layout guide, no bigger, no smaller.` |
| 가이드 색이 그대로 남음 | `Do not keep the flat guide colors, fully paint every area in the cartoon style.` |
