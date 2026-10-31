# 제미나이 프롬프트 — 도트 동굴 (세로 맵)

> 2026-10-29. 세로 화면 시안(`art/source/gemini/map-portrait/pixel-layout-empty.png`)의 동굴은 부드러운 그림체라 도트인 궁과 어울리지 않는다.
> 궁과 같은 도트 느낌으로 동굴만 새로 뽑는다.

## 쓰는 법
1. 제미나이에서 세로 시안을 만든 **그 대화**에 이어서 보내면 그림체가 가장 잘 맞는다 (새 대화여도 첨부 2장이면 충분).
2. 첨부: `art/preview/map-portrait/bg.png`(정리한 맵 전체), `art/preview/map-portrait/palace.png`(궁만 잘라 낸 것).
3. **영어 블록만** 복사해서 붙여 넣는다.
4. 결과 PNG를 Claude에게 넘기고 **"도트 동굴 넣어줘"** 라고 하면 된다.
   Claude가 하는 일: 하늘색 배경 제거 → 궁과 같은 도트 크기로 맞춤 → 맵 오른쪽 아래(지금 동굴 자리, 아래 길이 입구로 들어가게)에 배치 → 입구 안 보라색 반짝임 움직임(4프레임) → `map-portrait-cave` 교체·`map-portrait-bg` 다시 만들기.

배경을 **하늘색(#00FFFF)**으로 한 이유: 마젠타는 입구 안 보라색과, 초록은 이끼와 섞여서 지울 때 같이 지워진다.

## 프롬프트

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The first attached image is the map of my cute mobile tower-defense game, the second is the royal palace sprite from that map.
Draw a new monster cave entrance sprite for this map in EXACTLY the same pixel-art style as the palace:
- crisp square pixels of the same size as the palace pixels, no anti-aliasing, no blur, no soft painterly texture, no gradients
- a 1-pixel dark brown outline (#2A211C) around every shape
- light from the top-left, one flat lighter tone on top and one flat darker tone on the bottom-right
- the same bright, cheerful palette as the palace and the map

The cave: a cute, rounded mound of chunky grey-blue boulders, each rock a clear separate shape with simple 2-3 tone shading, like the stone platform of the palace. A few neat grass and moss patches and one small bush on top of the mound.
On the lower-left side of the mound, a big arched opening, dark inside (deep navy-purple, not pure black), with a few small purple sparkle pixels in the darkness.
The bottom edge of the opening is flat and level with the ground, so a dirt road can run straight into it from the left.
Korean touch: a twisted straw rope (geumjul) with small white paper strips hanging across the top of the opening.

View: the same top-down three-quarter angle as the palace.
Size: about 60% of the palace width, a little wider than tall.
Draw the whole cave fully, not cut off at any side, centered with empty space around it.
Background: one solid flat cyan color (#00FFFF). No ground, no road, no grass around it, no shadow on the background, no frame.
```

## 다시 뽑을 때 덧붙일 말
| 문제 | 덧붙일 영어 |
|---|---|
| 부드러운 그림처럼 나옴 | `More pixel art: bigger and chunkier pixels, flat colors, fewer shades, hard edges like the palace.` |
| 입구가 정면(가운데)에 있음 | `Move the opening to the lower-left side of the mound, facing left toward the road.` |
| 너무 무섭게 나옴 | `Make it cuter and friendlier, rounder rocks, no skulls, no sharp spikes.` |
| 금줄이 안 보임 | `Add the straw rope with white paper strips across the top of the opening, clearly visible.` |
| 배경에 땅·그림자가 생김 | `Only the cave on a plain flat cyan background, nothing else.` |
