# 제미나이 프롬프트 — 카툰 유닛 (창병부터)

> 2026-11-11. 맵을 카툰으로 확정(`gemini-cartoon-map-prompt.md`)했으니 유닛도 같은 그림체로 다시 뽑는다.
> 그림체 기준은 비교 때 B 시안 속 슬라임(`art/source/gemini/map-cartoon/style-ref-b.png`) — 맵과 같이 그려져서 가장 잘 어울렸다.
> 먼저 창병 4등급을 완성된 모습으로 받아 맵 위에서 느낌을 보고, 괜찮으면 같은 대화에서 **창을 뗀 몸 + 창만** 따로 받는다(공격할 때 창만 찌르기).

## 쓰는 법
1. 새 대화, 첨부 2장: `art/source/gemini/map-cartoon/map-v1.png`(새 맵) → `art/source/gemini/map-cartoon/style-ref-b.png`(슬라임 그림체 기준).
2. ①을 보낸다. 결과를 Claude에게 넘기고 **"카툰 창병 맵에 올려줘"** → 맵 위 미리보기 + 유니티 반영.
3. 마음에 들면 같은 대화에서 ②(창 뗀 몸 + 창만).

## ① 창병 4등급 (완성 모습)
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The first attached image is the map of my cute mobile tower-defense game. The second image shows red jelly slime spear soldiers drawn on that map: use exactly that art style for the units (clean, cute, smooth 2D cartoon, NOT pixel art, glossy jelly body, soft clean shading, gentle highlights, a thin dark outline, light from the top-left), so they match the map.

Draw my player units as a sprite sheet: 4 cute red jelly slime spear soldiers of the Korean Joseon dynasty, rank 1 to 4 from left to right, side by side, each centered in its own equal-width cell, all standing on the same baseline, facing the viewer.
Each slime: a soft round dome body, wider at the bottom with a flat base, two tiny round nub hands, no arms, no legs. A cute face: two big dark eyes with white shines, pink cheeks, a small smile. The spear is held upright in the slime's right nub hand (on the right side of the image), tip pointing straight up.
1. Recruit (smallest): an off-white cloth headband tied on the side, a short plain wooden spear.
2. Soldier: a black Joseon felt hat (jeollip) with a wide round brim and a red cord, an iron-tipped spear with a small red tassel.
3. Officer: the same black felt hat with a peacock feather, a navy blue sash across the lower body below the face, a longer iron spear.
4. General (biggest): a steel helmet with gold trim and a small red plume, a long spear with a gold fitting and a red tassel, standing on a low round dark-red pedestal. No cape, no armor.
Sizes grow a little from left to right (the general about 1.6 times as wide as the recruit).
Everything stays inside its own cell, nothing touching another unit.
Background: one solid flat cyan color (#00FFFF). No shadow, no ground, no frame.
```

## ② 창을 뗀 몸 + 창만 (같은 대화, ①이 마음에 들 때)
```
Perfect. Now draw the same sheet again in two rows, same image style, same sizes, same baseline:
Top row: exactly the same 4 slimes, same bodies, faces, hats and pedestal, but WITHOUT the spears, the right nub hand empty and slightly raised as if gripping.
Bottom row: only the 4 spears, each one alone, perfectly vertical, tip up, in the same cell as its slime above, same length and design as before.
Background: one solid flat cyan color (#00FFFF). No shadow, no ground, no frame.
```

## 다시 뽑을 때 덧붙일 말
| 문제 | 덧붙일 영어 |
|---|---|
| 맵 위에 그려서 나옴 | `Only the 4 units on a plain flat cyan background, no map.` |
| 도트처럼 나옴 | `Smooth cartoon, no pixels, like the slimes in the second image.` |
| 창이 기울거나 몸에 박힘 | `Spears perfectly vertical, held beside the body on the right, not crossing the face.` |
| 크기가 다 같음 | `Clearly different sizes: recruit small, general biggest.` |
