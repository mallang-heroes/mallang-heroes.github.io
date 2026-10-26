# 제미나이용 맵 소스 프롬프트

> 맵을 한 장으로 다 그리지 않고 **4가지로 나눠** 뽑습니다. 길은 몬스터 이동 경로와 정확히 맞아야 하고, 나무·돌은 유닛 배치를 막지 않게 Claude가 직접 배치해야 하기 때문입니다.
>
> | 순서 | 뽑을 것 | 첨부 | Claude에게 할 말 |
> |---|---|---|---|
> | ① | 맵 배경 (풀밭 + 길 + 동굴 자리) | `map-layout-guide.png` | **"맵 배경 추출해줘"** |
> | ② | 장식 시트 (나무·소나무·돌·덤불·꽃·풀) | ① 결과 | **"맵 장식 추출해줘"** |
> | ③ | 건물 시트 (궁 + 막사 6개) | ① 결과 | **"건물 추출해줘"** |
> | ④ | 몬스터 출현 동굴 | ① 결과 | **"동굴 추출해줘"** |
>
> 모두 **같은 대화창**에서 뽑으세요. ②~④는 ①의 결과 이미지를 첨부해서 그림체를 맞춥니다.
> 각 블록 안의 영어만 복사해서 붙여 넣으세요. 한국어 설명까지 붙여 넣으면 글자가 그림에 들어갑니다.

---

## ① 맵 배경

`map-layout-guide.png`(풀밭 위에 흙길 고리와 오른쪽 위 동굴 자리만 단색으로 그린 그림)를 첨부하고 보내세요.

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Repaint the attached layout image as a finished background for a cute mobile tower-defense game.
Keep the composition EXACTLY the same: same image size and aspect ratio, the dirt road loop in exactly the same position, width and shape, the short straight road going up to the cave at the top right, and the cave opening in the same spot. Do not move, bend, widen or narrow the road.

Style: cute casual mobile game art, soft painted shading, light from the top-left, clean but soft outlines, warm and bright colors, seen from slightly above.
Ground: soft green grass with gentle color variation and a few tiny grass blades, but keep it calm and low-detail so characters stand out.
Road: packed light-brown dirt path with darker brown edges, faint wheel ruts and a few tiny pebbles.
Cave: a small rocky cave mouth at the top right with a dark opening and a faint purple glow inside, where the road starts.
Do NOT add trees, rocks, flowers, buildings, characters, fences, water or any other objects. Only grass, the road and the cave.
No text, no UI, no frame, no vignette.
```

**확인할 것:** 길 모양과 위치가 가이드와 같은지(조금 어긋나는 건 Claude가 맞춥니다), 나무나 건물이 들어가지 않았는지.

---

## ② 장식 시트

①의 결과를 첨부하고 보내세요.

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

In exactly the same art style, lighting and colors as the attached map, draw a sheet of separate map decoration sprites for the same game, seen from the same slightly-above angle.
Draw each object separately with clear empty space between them, all on one solid flat magenta background (#FF00FF). No ground under them, no shadows on the background.

Objects:
three different round leafy trees (one round, one wide-spreading like a zelkova, one tall and narrow),
two Korean pine trees with red-brown curved trunks and flat layered needle clusters,
one small grey rock, one cluster of two grey rocks,
one small round green bush,
three small flower patches (white, pink azalea, yellow dandelion),
two small tufts of grass.

All trees about the same size as each other; rocks, bushes and flowers much smaller.
No text, no labels.
```

---

## ③ 건물 시트

①의 결과를 첨부하고 보내세요. 한 장에 다 안 들어가면 궁 1장, 막사 6개 1장으로 나눠도 됩니다(두 번째 요청에 "same scale and style as the previous image"를 붙이세요).

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

In exactly the same art style, lighting and colors as the attached map, draw a sheet of separate building sprites for the same cute mobile tower-defense game, front 3/4 view seen slightly from above.
Draw each building separately with clear empty space between them on one solid flat magenta background (#FF00FF). No ground, no shadows on the background.

1. A Joseon Korean royal palace main hall: two-tiered dark tiled roof with upturned eaves, red pillars, green and blue dancheong painted beams, stone stairs on a two-step stone platform, two small red flags. This is the largest building.
2. Six small barracks, all the same size, each about half the width of the palace, each with a different roof color and a clear identifying prop:
   - spear barracks: red roof, a wooden rack holding three spears beside it
   - archer barracks: green roof, a small watchtower with an archery target beside it
   - gunner barracks: purple roof, a stone fort with battlements and a small bronze cannon on a wheeled cart
   - cavalry barracks: ochre roof, a stable with a horse looking out and a pile of hay
   - navy barracks: blue roof, a small wooden dock over a patch of water with the front of a Korean panokseon warship
   - mystic barracks: charcoal grey roof, a small shrine with a yellow talisman banner and a wooden sotdae bird pole
Each building has a closed wooden double door facing the viewer.
No text, no labels, no Korean characters on signs.
```

---

## ④ 몬스터 출현 동굴

①의 결과를 첨부하고 보내세요. 문 안 보라색 기운의 움직임은 Claude가 만듭니다.

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

In exactly the same art style, lighting and colors as the attached map, draw one small rocky cave entrance sprite for the same game, front view seen slightly from above, centered and large in the frame.
A mound of grey rocks with an arched dark opening; inside the opening a soft swirling violet glow; a twisted straw rope (Korean geumjul) with small white paper strips hanging across the top of the opening.
Solid flat bright green background (#00FF00). No ground, no shadow on the background, no text.
```

> 동굴만 배경이 **초록**입니다. 보라색 기운이 마젠타 배경과 섞이면 지울 때 같이 지워지기 때문이에요.

---

## Claude가 하는 일

| 할 말 | Claude가 하는 일 |
|---|---|
| **"맵 배경 추출해줘"** | 위아래 여백 잘라 내기 → 보드 1560×720으로 맞춤 → 길 위치를 게임 경로와 비교해 어긋나면 보정 → 경로가 겹쳐 보이는 확인 이미지 |
| **"맵 장식 추출해줘"** | 배경 제거 → 장식별로 자르기·이름 붙이기 → 크기 맞춤(나무 약 60×70) → 유닛 배치 규칙대로 배치(길에서 45px, 나무 주변 70px 비움) |
| **"건물 추출해줘"** | 배경 제거 → 궁 160×131, 막사 88×56 크기로 → 정해진 자리에 배치 → 문 열림 3프레임(문 부분을 어둡게 바꿔서) |
| **"동굴 추출해줘"** | 배경 제거 → 70×62 크기 → 보라색 기운이 숨쉬는 4프레임 |
| (마지막) **"맵 합쳐줘"** | 레이어 합성 → 보드·폰 크기 미리보기 → 캐릭터 올려 보기 → Git 정리 |
