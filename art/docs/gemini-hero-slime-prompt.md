# 제미나이용 프롬프트 — 슬라임 진화 단계 (기본 슬라임 → 위인 슬라임)

## 진화 구조

| 단계 | 등급 | 모습 | 기준 이미지 |
|---|---|---|---|
| **기본 슬라임** | 군졸 · 정병 · 군관 · 장수 | 팔다리 없는 말랑한 젤리 몸. **등급마다 조금씩 자람** (군졸 아기 물방울 → 장수 양옆에 작은 손) · 모자·허리띠·무기 | `base-slime-ref-right.png` (콘셉트 시트의 슬라임) |
| **위인 슬라임** | 명장 · 천명 (공신은 명장 + 덧붙인 파츠) | **짧은 팔 두 개 + 짧은 다리 두 개**가 생겨 두 발로 걸음. 인물별로 따로 디자인 — 관모·투구, 대표 소품, (천명은) 빛나는 옥빛 수호령 | `yisunsin-slime.png`, `sejong-slime.png` |

- **명장·천명은 인물마다 각각 디자인**한다 (아래 표).
- **공신은 따로 그리지 않는다.** 명장 슬라임을 그대로 쓰고, 그 위에 각성 파츠(장식·오라 등)를 덧붙이는 방식. 공신용 파츠 프롬프트는 나중에 정해서 추가한다.
- 기본 슬라임 장수(양옆에 작은 손이 생긴 단계)에서 명장이 되면 팔다리가 자라난다.
- 천명: 한 판에 1명. 위인 슬라임 중 가장 화려하고, 등 뒤에 **옥빛으로 빛나는 수호령**(이순신의 거북선, 세종의 용 국새처럼)이 떠 있음.
- 기본 슬라임(군졸→정병→군관→장수로 조금씩 자라남)은 `제미나이 유닛 프롬프트.md`를 쓰세요.

### 몸 색
보내 주신 그림은 이순신이 빨강, 세종이 파랑인데, 지금 병과 색 규칙으로는 **이순신 = 수군(파랑), 세종 = 포수(보라)** 입니다. 아래 표는 병과 색으로 적어 두었습니다. 인물별 고유 색으로 가고 싶으면 `{BODY COLOR}`만 바꿔 넣으면 됩니다.

---

## 공통 그림체 문장 (모든 요청 맨 앞)

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.
Same art style as the attached reference images: cute glossy translucent jelly slime characters, soft painted shading, light from the top-left, clean dark outline, Korean history theme, mobile game sprite.
The character always faces RIGHT in a 3/4 view. Solid flat magenta background (#FF00FF). No floor, no shadow, no text, no labels, no frames.
```

---

## A. 위인 슬라임 기준 그림 (인물마다 1장)

이순신·세종 그림 두 장을 첨부하고 보내세요. 다른 인물을 뽑을 때도 이 두 장을 계속 첨부하면 그림체가 맞습니다.

```
[공통 그림체 문장]

Draw ONE evolved hero slime in the same design language as the attached Yi Sun-sin and Sejong slimes:
a pear-shaped glossy translucent {BODY COLOR} jelly body with highlights and small bubbles, big glossy eyes with highlights, rosy cheeks, a small cute mouth,
two short stubby jelly arms and two short stubby jelly legs with round feet, standing upright on two feet as if it can walk.
Hero: {HERO}.
Headwear: {HEADWEAR}.
Holding: {ITEM}.
{EXTRA}
Facing RIGHT in a 3/4 view, full body, centered and large in the frame. Arms and legs clearly separated from the body, not hidden behind items.
```

> **이순신을 다시 뽑을 때:** 보내 주신 그림의 칼은 일본도(가타나)에 가까워 보입니다. `{ITEM}`에 `a Korean hwando sword with a simple round guard and a plain wrapped handle, not a katana`를 넣어 주세요.

---

## B. 위인 슬라임 파츠 시트 (인물마다 1장, A 결과 첨부)

```
[공통 그림체 문장]

Use the attached hero slime as the exact reference (same design, colors, scale and lighting).
Draw a parts sheet for 2D cutout animation. Each part separately with clear empty space between parts:
1. The jelly body alone (no face, no arms, no legs, no headwear, no items, no aura)
2. The face alone (eyes, eyebrows, cheeks and mouth only), eyes open
3. The same face with eyes closed
4. The same face shouting with the mouth open (attack)
5. Front arm, 6. Back arm (stubby jelly arms, slightly longer at the shoulder end so they can overlap the body)
7. Front leg with foot, 8. Back leg with foot (slightly longer at the hip end)
9. The headwear alone
10. The held item alone
11. {EXTRA PART}  (the glowing spirit / cape / back item alone — skip if none)
Everything faces right. No shadow, no text, no labels.
```

---

## C. 공신 — 나중에 추가

명장 슬라임에 각성 파츠를 덧붙이는 방식으로 갈 예정입니다. 어떤 파츠를 붙일지 정해지면 이 자리에 프롬프트를 넣습니다.

---

## 인물별 빈칸 (영어 그대로 붙여 넣기)

### 천명 6명 — `{EXTRA}`에 수호령이 들어감

| 인물 | 병과 · `{BODY COLOR}` | `{HEADWEAR}` | `{ITEM}` | `{EXTRA}` |
|---|---|---|---|---|
| 광개토대왕 | 창병 · `crimson red` | `a Goguryeo royal gold crown with upright gold feather-shaped ornaments` | `a long spear with a steel blade and a red tassel` | `Behind it floats a glowing translucent jade stone stele like a guardian spirit.` |
| 주몽 | 궁병 · `forest green` | `a Goguryeo feathered cap with two tall bird feathers` | `a large Korean horn bow` | `Behind it floats a glowing translucent jade three-legged crow spirit.` |
| 세종 | 포수 · `royal purple` | `a black Joseon king's ikseongwan crown with gold phoenix patterns and two rounded wings at the back` | `a rolled scroll in one hand` | `Behind it floats a glowing translucent jade royal dragon seal.` |
| 김유신 | 기병 · `ochre gold` | `a small Silla gold crown with tree-branch shaped ornaments and a red headband` | `a straight Silla sword` | `Seven small glowing jade stars float behind it in the shape of the Big Dipper.` |
| 이순신 | 수군 · `ocean blue` | `a dark steel Joseon admiral's helmet with a gold brim, a small gold dragon crest, red plume and a scaled neck guard` | `a Korean hwando sword with a simple round guard and a plain wrapped handle, not a katana` | `Behind it floats a glowing translucent jade turtle-ship spirit with a dragon head.` |
| 전우치 | 술사 · `slate grey` | `a black Korean scholar's horsehair gat hat` | `a folding fan and a yellow paper talisman` | `Behind it floats a faint translucent jade afterimage clone of itself, like a magic double.` |

### 명장 12명 — 수호령 없음, `{EXTRA}`에 망토·소품 (공신은 이 디자인에 파츠를 덧붙임)

| 인물 | 병과 · `{BODY COLOR}` | `{HEADWEAR}` | `{ITEM}` | `{EXTRA}` |
|---|---|---|---|---|
| 윤관 | 창병 · `crimson red` | `a Goryeo general's round steel helmet with a red tassel` | `a long spear` | `A short red cape, and a small army banner on its back.` |
| 척준경 | 창병 · `crimson red` | `a red cloth headband with flowing ends` | `a long two-handed glaive held ready to charge` | `A fierce brave expression and a short torn red cape.` |
| 이지란 | 궁병 · `forest green` | `a fur-trimmed Jurchen-style round hat` | `a horn bow` | `A quiver of arrows on its back and a short green cape.` |
| 이성계 | 궁병 · `forest green` | `a Joseon general's steel helmet with a red plume` | `a large horn bow with a whistling arrow` | `A short green cape with gold trim.` |
| 문익점 | 포수 · `royal purple` | `a Goryeo scholar's black bokdu hat with two side flaps` | `a small bronze hand cannon on a wooden pole` | `A small cloth pouch spilling white cotton bolls at its waist.` |
| 장영실 | 포수 · `royal purple` | `a simple black Joseon official's cap` | `a small brass rain gauge in one hand and a wrench in the other` | `Tiny brass gears float around it.` |
| 계백 | 기병 · `ochre gold` | `a Baekje steel helmet with a red crest` | `a straight sword` | `A short ochre cape, standing proudly as a last-stand hero.` |
| 정년 | 기병 · `ochre gold` | `a Silla soldier's helmet with a feather` | `a long cavalry spear` | `A short ochre cape.` |
| 장보고 | 수군 · `ocean blue` | `a blue sailor's head wrap with a topknot` | `a curved sword` | `A small trade-ship flag on its back.` |
| 이억기 | 수군 · `ocean blue` | `a Joseon navy commander's helmet with a red plume` | `a Korean hwando sword, not a katana` | `A small navy command flag on its back.` |
| 원효대사 | 술사 · `slate grey` | `no hat, a monk's round shaved top with a soft shine` | `a dried gourd water dipper` | `A grey-and-brown Buddhist monk's kasaya robe sash and prayer beads.` |
| 사명대사 | 술사 · `slate grey` | `a monk-warrior's simple hood` | `a monk's staff with rings` | `A monk's kasaya sash worn over a light armor plate, and prayer beads.` |

> 실존 인물이라 **표준영정·드라마 배우처럼 보이게 그리지 않습니다.** 슬라임이라 얼굴은 모두 같은 귀여운 얼굴이고, 인물은 머리쓰개·소품·수호령으로만 구분합니다.

---

## 뽑은 뒤 Claude에게

인물별로 **A 기준 그림 + B 파츠 시트** 두 장을 올리고, 이렇게 말해 주세요.

> **"위인 슬라임 추출해줘 — 이순신(천명, 수군)"**

여러 명을 한꺼번에 올려도 됩니다. 파일 이름이나 메시지에 인물과 등급만 적어 주세요.

### Claude가 하는 일
- 배경 제거, 파츠 자르기, 워터마크 지우기, 오른쪽 보기로 맞추기
- 리깅: 몸통 + 팔 2 + 다리 2 + 머리쓰개 + 소품 + 수호령
- 애니메이션
  - 대기 4: 말랑하게 출렁임, 눈 깜빡임, 수호령이 위아래로 떠다님
  - 걷기 6: **두 다리를 번갈아 걷기**, 팔 흔들기 (기본 슬라임은 통통 뛰기)
  - 공격 8: 인물별 동작 (이순신 칼 베기, 세종 국새를 들어 빛 퍼뜨리기 등) + 외치는 표정
  - 등장·진화 6: 기본 슬라임(장수)이 빛에 싸였다가 팔다리가 돋아나는 연출 (천명은 금빛)
- @2x 시트·JSON(타격점·발사 지점), 맵 위 미리보기, Git PR
