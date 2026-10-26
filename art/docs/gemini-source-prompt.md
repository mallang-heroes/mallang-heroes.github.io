# 제미나이용 캐릭터 소스 프롬프트 (리깅용 파츠 시트)

> 제미나이에서 그림 소스를 뽑아 Claude에게 넘기면, Claude가 잘라서 관절을 잡고(리깅) 애니메이션·스프라이트 시트·JSON을 만든 뒤 Git에 올립니다.
> 캐릭터 한 종마다 **① 기준 그림 1장 → ② 파츠 시트 1장** 순서로 뽑으세요.

---

## 0. 뽑기 전에 알아둘 것

- **같은 대화창에서 계속** 뽑으세요. 캐릭터가 바뀌어도 그림체가 유지됩니다. 첫 결과가 마음에 들면 그 이미지를 다음 요청에 **참고 이미지로 첨부**하세요.
- 제미나이는 투명 배경을 잘 못 만듭니다. 대신 **단색 마젠타(#FF00FF) 배경**으로 받으세요. Claude가 이 색만 지웁니다. 캐릭터 안에 분홍·자주색이 들어가면 배경을 **단색 초록(#00FF00)** 으로 바꾸세요.
- 해상도는 **가장 큰 크기**로 받으세요. 캐릭터 한 명이 최소 512px 이상이어야 합니다.
- 그림자, 바닥, 글자, 테두리 칸은 넣지 않게 합니다. 지난번 시트처럼 칸 안에 "정면" 같은 글자가 들어가면 자를 때 섞입니다.

---

## 1. 그림체 고정 문장 (모든 요청 맨 앞에 붙이기)

```
Style lock for all images in this conversation:
cute chibi game character, about 2 heads tall, soft painted 3D-like shading, light from the top-left,
clean dark outline, Joseon dynasty Korean military look, readable at small mobile-game size.
The character always faces RIGHT in a 3/4 view.
Solid flat background color #FF00FF only — no floor, no shadow, no gradient, no text, no labels, no frames, no watermark.
```

---

## 2. 기준 그림 (완성 캐릭터 1장)

```
[그림체 고정 문장]

Draw ONE full-body character standing in a neutral ready pose, facing right in 3/4 view, centered, large in frame.
Character: {캐릭터 설명}
Weapon: {무기 설명}, held in the front (right-side) hand.
Keep both arms and legs clearly visible, not crossing the body.
```

---

## 3. 파츠 시트 (리깅용, 가장 중요)

기준 그림을 첨부하고 아래를 보내세요.

```
[그림체 고정 문장]

Using the attached character as the exact reference (same design, colors, proportions, scale and lighting),
draw a CHARACTER PARTS SHEET for 2D cutout animation.
Lay out each part SEPARATELY with clear empty space between them, all at the same scale as the reference, on the solid #FF00FF background:

1. Head with helmet and neck guard (eyes open, determined face)
2. Head again, eyes closed (for blinking)
3. Head again, mouth open shouting (for attack)
4. Torso with armor coat and belt — draw it COMPLETE, including the parts normally hidden behind the arms
5. Front arm (upper arm + forearm + hand as one piece), hand in a closed grip
6. Back arm (upper arm + forearm + hand as one piece), hand in a closed grip
7. Front leg with boot
8. Back leg with boot
9. Weapon alone: {무기 설명}, straight, full length
10. {장식 1}  (예: helmet plume / tassel as a separate piece)
11. {장식 2}  (예: back equipment)

Rules for every part:
- Add a little extra length at joint ends (shoulder top, hip top, neck bottom) so pieces can overlap when rotated.
- Do not cut off any part at the image edge.
- No shadows on the background, no text, no numbers, no labels.
```

> 제미나이가 한 장에 다 못 넣으면 **머리 3장** / **몸·팔·다리** / **무기·장식**으로 나눠 요청해도 됩니다. 크기만 같게 유지해 달라고 하세요("same scale as the previous parts sheet").

---

## 4. 캐릭터 설명 바꿔 끼우기

### 병과 (무기와 색)

| 병과 | 옷 색 | {무기 설명} | {장식} |
|---|---|---|---|
| 창병 | dark red `#9A3B2E` | a long spear with a steel leaf-shaped blade and a red tassel | red helmet plume |
| 궁병 | forest green `#3F6B3A` | a Korean recurve horn bow with tips curling backward | quiver of arrows on the back, feathers above the shoulder |
| 포수 | purple `#5E4E8C` | a short hand cannon on a wooden pole with three gold bands | gunpowder pouch and coiled fuse cord at the back of the waist |
| 기병 | ochre `#8A6418` | a flail: long wooden handle, short iron chain, short wooden striker | (기병은 말을 따로 요청 — 아래 5번) |
| 수군 | navy blue `#2E5E8C` | a single-edged curved Korean sword held blade-up | a wooden oar carried on the back, wide blade above the shoulder |
| 술사 | light gray `#8C9097` with charcoal trim | a wooden staff topped with a gold ring and two small bells | a yellow paper talisman in the back hand, prayer beads around the neck |

### 등급 (옷과 모자)

| 등급 | {캐릭터 설명} 앞부분 |
|---|---|
| 군졸 | a young soldier in plain white cotton clothes and a wide-brimmed black felt hat |
| 정병 | a soldier in a {병과 색} uniform and a wide-brimmed black felt hat with a red plume |
| 군관 | an officer in dark gray armor with silver studs and a steel helmet |
| 장수 | a general in {병과 색} padded armor coat with gold studs, steel helmet with gold brim and red plume, navy neck guard |

예) 궁병 정병 = `a soldier in a forest green uniform and a wide-brimmed black felt hat with a red plume` + 무기 `a Korean recurve horn bow ...`

### 콘셉트를 바꿀 때

- **슬라임:** {캐릭터 설명}을 `a cute translucent jelly slime creature in {병과 색}, glossy highlights and small bubbles inside, wearing a small tilted steel helmet with red plume and a studded belt, a stretchy jelly arm` 로. 파츠는 **몸통(얼굴 포함) · 투구 · 젤리 팔 · 무기 · 얼굴 3종(기본·눈 감음·외침)** 만.
- **메카:** `an original chibi mecha warrior inspired by Joseon armor: helmet-shaped robot head with a glowing cyan visor slit, {병과 색} armor plates with gold rivets on a gray frame, large shoulder pauldron, glowing chest core, back thruster pack` 로. 무기는 `{무기} with a glowing cyan energy blade`. 특정 작품처럼 보이지 않도록 `no V-shaped head fin, no face mask with vents` 를 꼭 붙이세요. 파츠에 **등 추진기**를 추가.

---

## 5. 기병 (말 따로)

말은 기수와 따로 뽑아야 리깅이 됩니다.

```
[그림체 고정 문장]

Draw a cute chibi warhorse parts sheet for 2D cutout animation, facing right, same style as the attached rider.
Dark brown coat, black mane and tail, saddle with an {병과 색} saddle cloth.
Separate parts with space between them on solid #FF00FF:
1. Body with saddle (no legs)
2. Neck + head with bridle
3. Front near leg, 4. Front far leg, 5. Back near leg, 6. Back far leg (each with hoof)
7. Tail
Add extra length at joint ends. No shadow, no text.
```

기수는 3번 파츠 시트에서 **다리 대신 "seated leg bent at the knee with a stirrup"** 하나로 요청하세요.

---

## 6. Claude에게 넘길 때

- 파일 이름 예: `spear-jangsu-ref.png`, `spear-jangsu-parts.png`, `cavalry-horse-parts.png`
- 함께 알려 줄 것: **병과 · 등급 · 콘셉트(귀여운 장수/슬라임/메카)**
- 받은 뒤 Claude가 하는 일: 배경(#FF00FF) 제거 → 파츠 분리·관절 지정 → 대기 4 / 공격 6 / 걷기 4 프레임 → @2x 시트 + JSON(타격·발사 지점) → 미리보기(GIF, 맵 위 보드·폰 크기) → Git 커밋

## 7. 결과 확인 체크리스트

- [ ] 오른쪽을 보는가 (반대면 Claude가 뒤집어도 되지만, 글자·문양이 거꾸로 될 수 있음)
- [ ] 배경이 한 가지 단색이고 그림자·글자가 없는가
- [ ] 파츠끼리 겹치지 않고 띄어져 있는가
- [ ] 머리·몸·팔 크기가 기준 그림과 같은 비율인가
- [ ] 몸통이 팔에 가려진 부분까지 다 그려져 있는가
