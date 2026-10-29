# 제미나이 프롬프트 — 도트 기본 슬라임 (군졸 → 정병 → 군관 → 장수)

> 2026-10-29. 세로 맵(도트 궁·도트 동굴)에 맞춰 기본 슬라임을 처음부터 다시 디자인한다.
> **먼저 창병 한 줄(4등급)만** 뽑아 맵에 올려 보고, 마음에 들면 같은 대화에서 나머지 5병과를 이어서 뽑는다.

## 쓰는 법
1. 도트 동굴을 뽑은 **그 제미나이 대화**에 이어서 보낸다 (그림체·도트 크기 유지에 가장 좋음).
2. 첨부: `art/preview/map-portrait/bg.png`(정리한 맵), `art/source/gemini/map-portrait/cave-pixel.png`(도트 동굴).
   예전 슬라임 그림은 **첨부하지 않는다** — 디자인을 새로 하기 위해서.
3. **영어 블록만** 붙여 넣는다.
4. 결과 PNG를 Claude에게 넘기고 **"슬라임 맵에 올려줘"** 라고 하면, 배경 제거 → 도트 정리 → 등급별로 잘라 배치 칸 크기에 맞춤 → 맵 칸 위에 올린 확인 그림을 만든다.

## 등급 설계 (프롬프트에 반영)
| 등급 | 크기(장수 = 100%) | 머리 | 무기(창병) | 기타 |
|---|---|---|---|---|
| 군졸 | 약 70% | 흰 천 머리띠 | 짧은 나무 창 | 가장 단순, 어리고 말랑 |
| 정병 | 약 80% | 검은 전립(벙거지) + 빨간 끈 | 쇠 날 창 + 붉은 술 | |
| 군관 | 약 90% | 전립 + 공작 깃털 + 구슬 끈(패영) | 같은 창, 더 길고 반짝임 | 남색 조끼 띠 |
| 장수 | 100% | 금테 투구 + 붉은 깃털 | 금장식 긴 창 + 큰 붉은 술 | 둥근 받침 (망토·갑옷 없음 — 위로 명장·천명·공신이 있으므로 절제) |

- 팔다리 없음. 몸 옆의 작은 동그란 손(손 마디)으로 무기를 듦.
- 무기는 **그림 오른쪽**에 든다(정면 대기 자세).
- 배경은 **하늘색(#00FFFF)** — 창병 몸이 빨강이라 마젠타와 섞이지 않게. 수군(파랑) 차례에는 마젠타로 바꾼다.

## ① 창병 4등급 (먼저 이것만)

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The attached images are the map and the cave sprite of my cute vertical mobile tower-defense game. Now design the player units in EXACTLY the same pixel-art style:
- crisp square pixels of the same size as the cave and palace pixels, no anti-aliasing, no blur, no gradients, no soft painterly texture
- a 1-pixel dark brown outline (#2A211C) around every shape
- light from the top-left: one flat lighter tone on top, one flat darker tone on the bottom-right
- the same bright, cheerful palette as the map

The units are cute slime soldiers of the Korean Joseon dynasty. Draw ONE slime in its 4 ranks, side by side in a row from left to right, all facing the viewer in a calm idle pose, seen from the same slightly-top-down angle as the map:

Body (same for all 4): a soft round jelly dome, wider at the bottom with a flat base, rounded top, NOT pointy, NOT a teardrop. Color: coral red (#F06A55) with a lighter top and a darker bottom edge, and one small white shine on the top-left. Two simple black dot eyes, small pink cheeks, a tiny happy mouth. NO arms and NO legs; only two tiny round nub hands on the sides of the body.
Each slime holds its spear upright with the nub hand on the RIGHT side of the picture.

1. Recruit (smallest, about 70% of the general's body size): a plain white cloth headband tied at the back, a short plain wooden spear. Very simple.
2. Soldier (about 80%): a black Joseon felt soldier hat (jeollip) with a wide round brim and a red cord, an iron-tipped spear with a small red tassel.
3. Officer (about 90%): the same black felt hat with a peacock feather on the side and a string of small beads hanging from the brim, a navy blue sash across the body, a longer shining iron spear.
4. General (the biggest, 100%): a gold-trimmed Joseon steel helmet with a red plume, a long spear with gold fittings and a big red tassel, standing on a small flat round pedestal in a slightly darker red. No cape, no cloak, no armor plates: keep it modest, because higher hero ranks come after the General.

All four must clearly look like the same character growing up: same face, same body shape and color, only bigger with better gear.
The weapon may stick out above the head. Leave clear empty space between the four slimes.
Background: one solid flat cyan color (#00FFFF). No ground, no grass, no shadow on the background, no frame.
```

## ①-b 진짜 도트로 다시 (첫 결과가 부드러운 그림처럼 나왔을 때)

> 첫 결과(2026-10-29 `art/source/gemini/slime-pixel/spear-ranks.png`)는 "pixel-art style"을 넣었는데도 도트 격자가 없고 몸에 그라데이션이 들어갔다.
> 동굴 픽셀 크기를 따라 하라고 한 것도 원인 — 동굴 자체가 잔 도트(약 167도트 폭)라서 슬라임도 잘게 그렸다.
> 그래서 **도트 개수를 숫자로** 못 박는다. 장수 몸 폭 20도트 = 보드 약 50 (1도트 = @2x 5px), 칸 63 안에 들어간다.
> Claude가 기계로 줄여서 도트를 만들어 보면 얼굴이 뭉개져서 쓸 수 없었다 → 제미나이가 처음부터 적은 도트로 그려야 한다.

같은 대화에서 그대로 보낸다 (첨부 없이).

```
Redraw the same 4 slimes as REAL low-resolution pixel art sprites, like a 16-bit console game.
Hard rules:
- Count the art pixels: the General's body is only 20 art pixels wide, the Officer 18, the Soldier 16, the Recruit 14 (hats, plume, pedestal and spear are extra).
- Draw every art pixel as one big square block of exactly the same size (about 12 by 12 screen pixels), all blocks aligned to one grid, so the pixels are clearly visible.
- Flat colors only: every color area is one solid color, at most 3 tones per material (highlight, base, shadow). No gradients, no soft shading, no anti-aliasing, no blur.
- A 1-art-pixel dark brown outline (#2A211C) around every shape.
- Eyes are tiny black blocks (1 art pixel wide, 2 tall), cheeks are 2 pink art pixels, the mouth is 2-3 dark art pixels.
Keep the same designs: white headband / black felt hat with red cord / felt hat with peacock feather and bead string and navy sash / gold-trimmed helmet with red plume on a round pedestal, no cape. Spear on the right side of the picture.
Same order in one row, clear space between them, solid flat cyan background (#00FFFF), no ground, no shadow.
```

## ①-c 도트 견본을 첨부해서 새 대화로 (①-b도 안 될 때 — 2026-10-29 실제로 안 됨)

> ①-b를 같은 대화에 보냈더니 제미나이가 앞 그림을 거의 그대로 돌려줬다(바뀐 픽셀 0.3%, `spear-ranks-retry1.png`).
> 같은 대화에서는 '앞 그림 고치기'로 받아들여서 새로 그리지 않는다 → **새 대화**를 열고,
> Claude가 직접 찍은 **도트 견본** `art/source/pixel/slime-body-template.png`(장비 없는 몸 14·16·18·20도트, 1도트 = 12px)를 첨부해 도트 크기를 그림으로 보여 준다.
> 첨부는 이 견본 1장만 (부드러운 첫 결과를 같이 넣으면 다시 부드럽게 그린다).

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

The attached image is a pixel-art template I made: 4 plain slime bodies, 14, 16, 18 and 20 art pixels wide, each art pixel drawn as a 12 by 12 square block.
Keep EXACTLY this pixel size, grid, outline, flat colors and these 4 body sizes. Only add headgear, a spear and small details on top of each body, drawn with the same big square pixels:

1. Recruit (14 px body): a white cloth headband tied on the side, a short plain wooden spear held on the right side of the picture.
2. Soldier (16 px body): a black Joseon felt soldier hat (jeollip) with a wide round brim and a red cord, an iron-tipped spear with a small red tassel.
3. Officer (18 px body): the same black felt hat with a small peacock feather and a short string of beads from the brim, a navy blue sash across the body, a longer iron spear.
4. General (20 px body): a gold-trimmed steel helmet with a red plume, a long spear with a gold fitting and a red tassel, the body standing on a flat round dark-red pedestal. No cape, no armor.

Rules: true pixel art, every pixel a hard square of the same size on one grid, flat colors with at most 3 tones per material, a 1-pixel dark brown outline (#2A211C), no gradients, no anti-aliasing, no blur, do not redraw the bodies smoother or bigger.
Same row layout, same solid flat cyan background (#00FFFF), no ground, no shadow.
```

## 다시 뽑을 때 덧붙일 말
| 문제 | 덧붙일 영어 |
|---|---|
| 몸이 뾰족하거나 물방울 모양 | `Rounder jelly dome with a flat base, not pointy, not a teardrop.` |
| 등급 차이가 작음 | `Make the size difference between ranks clearer, and the gear clearly richer at each rank.` |
| 도트가 너무 잘거나 부드러움 | ①-b 프롬프트를 쓴다 (도트 개수를 숫자로 지정) |
| 팔다리가 생김 | `No arms and no legs, only two tiny round nub hands.` |
| 4마리 얼굴이 다름 | `Keep exactly the same face and body color on all four.` |

## ② 나머지 병과 (창병이 마음에 든 뒤, 같은 대화에서)

```
Great. Now draw the same 4 ranks again for a different unit type, with exactly the same body shape, face, size progression, headgear progression (headband, felt hat, felt hat with peacock feather and bead string, gold-trimmed helmet with plume) and pixel style as the spear slimes.
Body color: [BODY COLOR]. Weapon for each rank: [WEAPONS]. Extra: [EXTRA]
Background: one solid flat [BACKGROUND] color. No ground, no shadow, no frame.
```

| 병과 | BODY COLOR | WEAPONS (군졸 → 장수) | EXTRA | BACKGROUND |
|---|---|---|---|---|
| 궁병 | leaf green (#74C95E) | a small plain wooden bow → a curved Korean bow → a bigger curved bow with a quiver on the back → a gold-trimmed horn bow with a full quiver | — | magenta (#FF00FF) |
| 포수 | lavender purple (#A486E0) | a short bamboo fire tube → a black matchlock musket → a longer musket with a powder pouch → a gold-banded hand cannon | — | cyan (#00FFFF) |
| 기병 | amber orange (#F0B145) | a wooden club → a flail (handle, short chain, iron head) → a longer flail → a gold flail | the Soldier, Officer and General ride a small cute brown pony drawn in the same style; the Recruit has no pony | cyan (#00FFFF) |
| 수군 | sky blue (#55A6EA) | a wooden oar → a Korean sword (hwando) held blade up → a longer sword with a small oar on the back → a gold-hilted sword | — | magenta (#FF00FF) |
| 술사 | light grey (#B4BBC5) | a paper talisman → a big calligraphy brush → a brush and a prayer-bead necklace → a gold brush with a floating yellow talisman | — | magenta (#FF00FF) |
