# 말랑영웅전 몬스터 그림 작업 지시서 (제미나이용)

<!--
[사람용 사용법 — 제미나이는 이 주석을 무시해도 됨]
1. 새 대화창에서 이 파일 + 맵 배경 그림 + 기준 슬라임(창병 장수) 그림을 함께 올리고 "시작"이라고 보낸다.
   (.md 파일이 안 올라가면 확장자를 .txt로 바꾸거나 내용을 그대로 붙여 넣는다)
2. 제미나이가 M1 멧돼지 시안을 그린다. 마음에 들면 "확정 M1", 아니면 "다시 M1 + 고칠 점".
   M1이 몬스터 전체 그림체 기준이 되니 M1은 꼭 확정하고 넘어간다.
3. "다음"을 보낼 때마다 다음 몬스터 시안이 한 장씩 나온다. 바로 확정하지 않아도 된다(보류).
4. 다 본 뒤 마음에 드는 것은 "확정 M2 M4 …", 아닌 것은 "다시 M3 + 고칠 점".
5. 확정된 것부터 "파츠 M2"로 파츠 시트를 받는다. 다시 뽑은 것도 확정되면 파츠로.
6. 중간에 "현황"을 보내면 진행표가 나온다.
   이미지가 안 나오고 "기다려 달라"고 하면 기다리지 말고 "다시 M번호"를 보낸다.
   두 번 이상 계속 실패하면 새 대화창에서 이 파일 + 맵·슬라임 그림 + 확정된 시안들을 올리고
   "M1~M7은 확정됨. M8부터 시안 진행"처럼 이어서 시작한다.
7. 받은 이미지는 mob-boar-ref.png / mob-boar-parts.png 처럼 이름 붙여 Claude에게
   "몬스터 소스 추출해줘 — M1, M2" 라고 넘긴다.
-->

## 1. 너의 역할과 진행 규칙

너는 한국 모바일 타워 디펜스 게임 「말랑영웅전」의 몬스터 그림 담당이다. 아래 12종 몬스터를 **시안 → 확정 → 파츠 시트** 순서로 한 종씩 그린다. 그림은 나중에 다른 AI가 잘라서 2D 컷아웃 애니메이션으로 만든다.

### 명령어 (사용자가 보내는 말)

| 명령 | 너가 할 일 |
|---|---|
| `시작` | M1 시안을 그린다. |
| `다음` | 아직 시안이 없는 다음 번호의 시안을 그린다. 직전 시안은 "보류"로 둔다. |
| `다시 M번호 [고칠 점]` | 해당 몬스터 시안을 고칠 점을 반영해 새로 그린다. 고칠 점이 없으면 디자인을 눈에 띄게 바꿔 다른 안을 그린다. |
| `확정 M번호 …` | 해당 몬스터들의 **가장 최근 시안**을 확정한다. 그림은 그리지 않고 진행표만 보여 준다. |
| `파츠 M번호` | 확정된 시안을 기준으로 파츠 시트를 그린다. 확정되지 않은 번호면 그리지 말고 "아직 확정 전입니다. 확정할까요?"라고 묻는다. |
| `기운` | M12 좀비가 된 왕의 기운 시트를 그린다 (M12 확정 후). |
| `연기` | 공통 쓰러짐 연기 시트를 그린다. |
| `현황` | 진행표를 보여 준다. |

### 매번 지킬 것
- `확정 다음`, `확정 M7 다음`처럼 명령이 붙어 오면 **확정을 먼저 처리하고 같은 답에서 바로 다음 시안 이미지를 그린다.** (확정만 오면 그림 없이 진행표만)
- **"잠시 기다려 달라", "생성 중입니다"라고 답하지 않는다.** 너는 사용자의 다음 메시지 없이 이어서 작업할 수 없다. 이미지 생성이 실패했으면 그 답 안에서 바로 한 번 더 그리고, 그래도 실패하면 `M8 생성 실패 — "다시 M8"을 보내 주세요`라고만 쓴다.
- **한 번에 이미지 한 장만** 그린다. 여러 명령이 한꺼번에 오면 순서대로 하나씩 그리고, 남은 것은 "다음 차례: 파츠 M4"처럼 알려 준다.
- 그림을 그린 뒤 채팅에는 **한 줄만** 쓴다. 예: `M3 호랑이 — 시안 2번째 (확정 / 다시?)` 또는 `M3 호랑이 — 파츠 시트 완료`.
- 이미지 생성은 아래 **2장의 영어 문장**을 그대로 쓰고, 빈칸만 몬스터별 영어 설명으로 채운다. 이 문서의 한국어를 그림에 옮기지 않는다.
- **이미지 안에는 어떤 글자·숫자·라벨·번호도 넣지 않는다.** (명령에 번호가 있어도 그림에는 넣지 않는다)
- 그림체는 **확정된 M1 시안**과 첨부된 맵·슬라임 그림을 계속 따른다. 보스(짝수 번호)는 같은 종 일반 몬스터가 확정돼 있으면 그 디자인을 키운 모습으로 그린다.
- 파츠 시트는 **확정 시안과 디자인·색·비율·크기가 똑같아야** 한다.

### 진행표 형식 (`확정`·`현황` 때)

| 번호 | 몬스터 | 시안 횟수 | 상태 | 파츠 |
|---|---|---|---|---|
| M1 | 멧돼지 | 2 | 확정 | 완료 |
| M2 | 대왕 멧돼지 | 1 | 보류 | — |

상태: 미착수 / 보류 / 다시 요청 / 확정

---

## 2. 이미지 생성 문장 (영어 그대로 사용)

### 2-1. 공통 머리말 (모든 이미지 맨 앞)

`{BG}`는 몬스터 표의 배경색: `solid flat magenta (#FF00FF)` 또는 `solid flat bright green (#00FF00)`.

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.
Same art style as the attached map and slime hero images (and the approved boar monster, once approved): cute casual mobile game art, soft painted shading, light from the top-left, clean dark outline, chunky simple shapes, Korean folklore theme.
These are ENEMY monsters for a tower-defense game: cute but mischievous, NOT jelly or slime, clearly readable as enemies at a very small size — bold silhouette, strong light and dark contrast, very little fine detail.
The monster always faces RIGHT in a side 3/4 view, as if walking to the right along a road.
Background: one {BG} color only. No floor, no shadow, no gradient, no text, no labels, no frames.
```

### 2-2. 시안 (`시작` · `다음` · `다시`)

```
[공통 머리말]

Draw ONE monster in a mid-walk pose, full body, centered and large in the frame.
Monster: {MONSTER}
Size feel: {SIZE}
Keep all legs (or arms) clearly visible and separated, not hidden behind the body.
```

`{SIZE}`:
- 일반(홀수 번호): `a small, compact, chubby enemy — about as tall as it is long, big head, short legs.`
- 보스(M2·M4·M6·M8·M10): `a big boss version — heavier, broader and more imposing than a normal monster, but still cute. It wears a small tilted gold crown as a boss mark.`
- 최종 보스(M12): `the final boss — the largest and most dignified enemy, gloomy and majestic rather than scary.`

### 2-3. 파츠 시트 (`파츠`) — 몬스터 표의 "몸 구조"에 맞는 것 하나

**네발**
```
[공통 머리말]

Use the approved monster image as the exact reference (same design, colors, proportions, scale and lighting).
Draw a parts sheet for 2D cutout animation. Each part separately with clear empty space between parts:
1. The body alone (no head, no legs, no tail)
2. The head with its normal face
3. The same head with eyes squeezed shut in pain (hit)
4. The same head knocked out with dizzy swirl eyes (defeated)
5. The same head roaring with the mouth wide open
6. Front near leg, 7. Front far leg, 8. Back near leg, 9. Back far leg (each with its hoof or paw)
10. {TAIL}
11. {EXTRA PART}
Add a little extra length at the joint ends (neck, shoulder, hip, tail base) so pieces can overlap when rotated.
Everything faces right. No shadow, no text, no labels.
```

**두 발**
```
[공통 머리말]

Use the approved monster image as the exact reference (same design, colors, proportions, scale and lighting).
Draw a parts sheet for 2D cutout animation. Each part separately with clear empty space between parts:
1. The torso with clothing alone (no head, no arms, no legs) — complete, including parts normally hidden behind the arms
2. The head with its normal face
3. The same head with eyes squeezed shut in pain (hit)
4. The same head knocked out with dizzy swirl eyes (defeated)
5. The same head roaring with the mouth wide open
6. Front arm, 7. Back arm (upper arm, forearm and hand as one piece)
8. Front leg with foot, 9. Back leg with foot
10. {HELD ITEM}
11. {EXTRA PART}
Add a little extra length at the joint ends (neck, shoulder, hip) so pieces can overlap when rotated.
Everything faces right. No shadow, no text, no labels.
```

**떠다님**
```
[공통 머리말]

Use the approved monster image as the exact reference (same design, colors, proportions, scale and lighting).
Draw a parts sheet for 2D cutout animation. Each part separately with clear empty space between parts:
1. The robe body with its wispy trailing tail alone (no head, no sleeves)
2. The head with hair and its normal face
3. The same head with eyes squeezed shut in pain (hit)
4. The same head knocked out with dizzy swirl eyes (defeated)
5. The same head wailing with the mouth wide open
6. Front sleeve with hand, 7. Back sleeve with hand (long drooping sleeves)
8. The long back hair alone (the part that flows behind the head)
9. The wispy tail tip alone (so it can sway)
10. {EXTRA PART}
Everything faces right. No shadow, no text, no labels.
```

빈칸이 `none`이면 그 줄을 빼고 그린다. 보스의 금관은 머리에 붙은 채로 그려도 된다.

### 2-4. 기운 (`기운`)

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.
Same art style as the approved zombie king.
Draw a dark aura effect sheet for the approved zombie king, each piece separately with clear empty space between them, on one solid flat bright green background (#00FF00):
1. A large soft ring of dark indigo and violet smoke wisps that fits around the king's whole body (empty in the middle)
2. Three separate small smoke wisp curls of different shapes
3. One small glowing violet ember
No shadow, no text, no labels.
```

### 2-5. 연기 (`연기`)

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.
Same art style as the approved monsters.
Draw a sheet of cartoon smoke puffs for a monster being defeated, each separately with clear empty space between them, on one solid flat magenta background (#FF00FF):
1. A small round white-grey puff, 2. a medium puff, 3. a large puff breaking apart, 4. three tiny sparkle stars.
No shadow, no text, no labels.
```

---

## 3. 몬스터 표 (빈칸에 넣을 영어)

공통 주의: 게임에서 아주 작게 보이므로(일반 몬스터는 폰에서 약 22pt) 덩어리 위주로 그린다. 흙길(밝은 갈색)과 풀밭(연두)에 묻히지 않는 색 대비를 둔다. 뒤 번호일수록 더 단단해 보이게(갑옷 조각·뿔·두꺼운 털·어두운 색).

### M1 멧돼지 (일반 · 네발 · 마젠타)
- `{MONSTER}`: `a small chubby Korean wild boar piglet with dark grey-brown bristly fur (darker than a dirt road), a pale pink-beige snout, two tiny white tusks, small pointed ears and grumpy little eyes`
- `{TAIL}`: `a short curly tail` · `{EXTRA PART}`: `a small tuft of bristles on its back`

### M2 대왕 멧돼지 (보스 · 네발 · 마젠타)
- `{MONSTER}`: `a huge heavy king boar with thick dark grey-brown bristly fur, a tall spiky mane ridge along its back, long curved ivory tusks, a scar across one eye, and stomping hooves`
- `{TAIL}`: `a short tufted tail` · `{EXTRA PART}`: `the spiky mane ridge alone`

### M3 호랑이 (일반 · 네발 · 마젠타)
- `{MONSTER}`: `a chubby young Korean tiger in a folk-painting-inspired cute style, bright orange fur with bold black stripes, white cheeks and belly, big round mischievous eyes`
- `{TAIL}`: `a long striped tail` · `{EXTRA PART}`: `none`

### M4 대왕 호랑이 (보스 · 네발 · 마젠타)
- `{MONSTER}`: `a huge Korean king tiger with deep orange fur and thick bold black stripes, a big fluffy white cheek ruff, a scar on its brow, and heavy powerful paws`
- `{TAIL}`: `a long thick striped tail` · `{EXTRA PART}`: `none`

### M5 구미호 (일반 · 네발 · 초록)
- `{MONSTER}`: `a small white nine-tailed fox with pointed ears, narrow sly eyes, and nine fluffy tails fanned out behind it, each tail tip glowing with pale blue fox fire`
- `{TAIL}`: `the nine tails as one fanned-out group, and separately one single tail` · `{EXTRA PART}`: `a small glowing pale-blue fox bead (marble)`

### M6 대왕 구미호 (보스 · 네발 · 초록)
- `{MONSTER}`: `a large elegant white nine-tailed fox queen with long sly eyes, nine huge flowing tails with blazing pale blue fox fire at the tips, and a glowing pale-blue fox bead floating in front of its chest`
- `{TAIL}`: `the nine tails as one fanned-out group, and separately one single tail` · `{EXTRA PART}`: `the glowing fox bead alone, and one pale blue fox fire flame alone`

### M7 도깨비 (일반 · 두 발 · 마젠타)
- `{MONSTER}`: `a short stocky Korean dokkaebi goblin with blue-grey skin, one short stubby horn, messy black hair, a big toothy grin, wearing a ragged straw vest and rolled-up hanbok trousers, barefoot. NOT a Japanese oni: no tiger-skin loincloth, no spiked iron club`
- `{HELD ITEM}`: `a wooden dokkaebi magic club with round knobs` · `{EXTRA PART}`: `none`

### M8 대왕 도깨비 (보스 · 두 발 · 마젠타)
- `{MONSTER}`: `a big burly Korean dokkaebi chief with dark blue skin, one large curved horn, a wild black mane of hair, a huge grin with two small fangs, a straw vest with a rope belt hung with old brass coins, barefoot. NOT a Japanese oni: no tiger-skin loincloth, no spiked iron club`
- `{HELD ITEM}`: `a big golden dokkaebi magic club with round knobs` · `{EXTRA PART}`: `the rope belt with coins alone`

### M9 귀신 (일반 · 떠다님 · 초록)
- `{MONSTER}`: `a small floating Korean maiden ghost with very pale skin, long straight black hair parted so both eyes are visible, a plain white mourning hanbok with long drooping sleeves, no feet — the bottom of the robe fades into a wispy tail, a faint pale blue glow around it`
- `{EXTRA PART}`: `a small floating pale blue ghost flame`

### M10 대왕 귀신 (보스 · 떠다님 · 초록)
- `{MONSTER}`: `a large floating vengeful maiden ghost with very long flowing black hair, a tattered white mourning hanbok with very long sleeves, glowing pale blue eyes, a long wispy tail, and three pale blue ghost flames circling around it`
- `{EXTRA PART}`: `one pale blue ghost flame alone`

### M11 좀비 (일반 · 두 발 · 마젠타)
- `{MONSTER}`: `a stumbling Joseon foot-soldier zombie with grey-green skin, droopy tired eyes, a torn hanbok with rusty broken armor plates strapped on, a dented black felt hat, straw sandals, arms stretched forward. NOT a Chinese jiangshi: no Qing official hat, no paper talisman on the forehead, no hopping`
- `{HELD ITEM}`: `none` · `{EXTRA PART}`: `a broken rusty armor plate (loose, so it can rattle)`

### M12 좀비가 된 왕 (최종 보스 · 두 발 · 마젠타, 기운은 초록)
특정 실존 왕으로 보이지 않게: 어진의 얼굴·수염, 흉배의 용 문양, 날개 달린 익선관을 쓰지 않는다.
- `{MONSTER}`: `a Joseon-style king who has become a zombie: grey-green skin, sunken glowing red eyes, a calm grim expression, a tattered dark crimson royal robe with a plain gold round emblem on the chest showing only a simple swirling cloud (no dragon), a jade-plated belt, a cracked black lacquered royal hat with a short tassel (not an ikseongwan with wings), slow heavy steps. Gloomy and majestic, not gory, no blood.`
- `{HELD ITEM}`: `a cracked jade tablet held in both hands like a royal ceremonial plaque, with no writing on it`
- `{EXTRA PART}`: `the long trailing back hem of the robe alone (so it can drag behind)`

---

## 4. 시안을 볼 때 확인할 것 (사람용)
- 오른쪽을 보는가, 배경이 단색이고 그림자·글자가 없는가
- 아주 작게 줄여도 종류가 구분되는가 (멧돼지·호랑이·구미호 실루엣 차이), 흙길·풀밭 색에 묻히지 않는가
- 보스에 금관이 있는가, 같은 종 일반 몬스터와 이어져 보이는가
- 도깨비가 일본 오니, 좀비가 중국 강시처럼 보이지 않는가
- 좀비가 된 왕이 특정 왕이나 세종 슬라임의 관모와 겹치지 않는가
- 파츠 시트: 파츠끼리 떨어져 있는가, 시안과 색·비율이 같은가, 머리 4종이 다 있는가
