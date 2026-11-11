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


## ③ 팔 달린 새 디자인 (2026-11-11, 찌르기 모션용)

> 손이 몸에 붙은 작은 혹이라 창을 들고 찌르는 동작이 어색하다 → **짧고 통통한 팔**을 단 디자인으로 바꾼다.
> 그림체·장비는 ①(`spear-sheet-v1.png`) 그대로. 먼저 대기 자세 4등급(③-1)을 받아 맵 위에서 확인하고,
> 마음에 들면 같은 대화에서 공격 자세(③-2: 준비·찌르기)를 받는다. 공격은 오른쪽으로 찌르는 그림 하나만 받고 왼쪽은 뒤집어 쓴다.
> 새 대화, 첨부 2장: `art/source/gemini/map-cartoon/map-v1.png` → `art/source/gemini/unit-cartoon/spear-sheet-v1.png`.

### ③-1 대기 자세
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The first attached image is the map of my cute mobile tower-defense game. The second image is my current unit sheet: 4 red jelly slime spear soldiers. Keep exactly that art style (clean, cute, smooth 2D cartoon, NOT pixel art, glossy jelly body, soft shading, thin dark outline, light from the top-left), the same colors, faces, hats, helmet, sash, pedestal and spears.

Redesign only the arms: give each slime two short, chubby, soft jelly arms (same red jelly as the body, rounded mitten hands, no fingers), long enough to really grip and thrust a spear, like a cute chibi character. Still no legs, the round dome body sits on a flat base.
Draw the same 4 ranks side by side, rank 1 to 4 from left to right (recruit, soldier, officer, general), each centered in its own equal-width cell, same baseline, facing the viewer in a relaxed standing pose. Each slime holds its spear upright in its right hand (the hand on the left side of the image), the other arm resting at its side.
Sizes grow a little from left to right (the general about 1.6 times as wide as the recruit). Everything stays inside its own cell.
Background: one solid flat cyan color (#00FFFF). No shadow, no ground, no frame.
```

### ③-2 공격 자세 (같은 대화, ③-1이 마음에 들 때)
```
Perfect. Now draw the attack poses of exactly these 4 slimes (same design, colors, sizes, gear), all turned slightly to face the RIGHT side of the image, in two rows:
Top row, READY pose: the body leans back and squashes a little, both hands grip the spear and pull it back, the spear held horizontally at chest height pointing right, ready to thrust.
Bottom row, THRUST pose: the body stretches forward to the right, both arms push the spear straight forward to the right with full force, the spear horizontal and extended far to the right, a determined cute face.
Each slime in the same cell column as before (rank 1 to 4 from left to right), all on the same baseline per row, nothing touching another cell.
Background: one solid flat cyan color (#00FFFF). No shadow, no ground, no frame, no motion lines.
```

| 문제 | 덧붙일 영어 |
|---|---|
| 팔이 너무 길어 사람처럼 됨 | `Shorter, chubbier arms, still a round cute slime, the arms only about one third of the body height.` |
| 장비·얼굴이 바뀜 | `Keep the hats, helmet, sash, pedestal, spears and faces exactly like the attached sheet.` |
| 찌르기 그림이 왼쪽을 봄 | `All attack poses face and thrust to the RIGHT.` |


## ④ 슬라임 새 디자인 — 맵만 첨부 (2026-11-11)

> ③처럼 지금 창병 시트를 첨부하면 제미나이가 그 그림을 그대로 베낀다 → **맵 한 장만** 첨부하고 디자인은 글로만 설명해서 처음부터 새로 뽑는다.
> 새 대화, 첨부 1장: `art/source/gemini/map-cartoon/map-v1.png`. 공격 자세는 ③-2를 같은 대화에서 이어 보낸다.

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The attached image is the map of my cute vertical mobile tower-defense game. Design brand-new player units that look like they belong on this map: the same clean, cute, smooth 2D cartoon style (NOT pixel art), soft clean shading, gentle highlights, a thin dark outline, light from the top-left, the same cheerful palette.

The units are cute red jelly slime soldiers of the Korean Joseon dynasty, armed with spears. Character design:
- body: a glossy, squishy red jelly slime, a soft round dome slightly wider at the bottom with a flat base, no legs
- arms: two short, chubby, soft jelly arms of the same red jelly, with rounded mitten hands (no fingers), long enough to firmly grip a spear with both hands and thrust it forward
- face: big shiny dark eyes with white highlights, small pink cheeks, a small smile, cute but brave
Draw a sprite sheet of 4 ranks side by side, rank 1 to 4 from left to right, each centered in its own equal-width cell, all standing on the same baseline, facing the viewer, holding a spear upright in one hand with the other arm relaxed:
1. Recruit (smallest): a plain off-white cloth headband, a short plain wooden spear.
2. Soldier: a black Joseon felt soldier hat (jeollip) with a wide round brim and a red cord, an iron-tipped spear with a small red tassel.
3. Officer: the same black felt hat with a peacock feather, a navy blue sash around the lower body, a longer iron spear.
4. General (biggest): a steel helmet with gold trim and a small red plume, a long spear with a gold fitting and a red tassel, the slime standing on a low round dark-red pedestal. No cape, no armor.
Sizes grow a little from left to right (the general about 1.6 times as wide as the recruit). Everything stays inside its own cell, nothing touching another unit.
Background: one solid flat cyan color (#00FFFF). No shadow, no ground, no frame.
```
