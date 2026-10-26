# 제미나이용 유닛 프롬프트 — 기본 슬라임 (군졸 · 정병 · 군관 · 장수, 24종)

> 말랑영웅전의 유닛은 **위인이 슬라임으로 소환된 모습**이다. 이 문서는 **기본 슬라임(팔다리 없음)** 용이고, 명장·천명은 `제미나이 위인 슬라임 프롬프트.md`를 쓴다.
>
> **제미나이가 병과별 완성 그림을 통째로 그린다.** (모자·허리띠를 따로 그려 얹으면 젤리에 씌운 느낌이 나지 않아서 바꿈.)
> Claude는 배경 제거·자르기·크기 맞추기·애니메이션(출렁임·통통 뛰기·공격)·시트·JSON만 맡는다.

## 병과마다 3장씩 (A 1장 + B 2장)

| 순서 | 뽑을 것 | 첨부 |
|---|---|---|
| A | **성장 라인업**: 같은 병과의 군졸 · 정병 · 군관 · 장수 4마리를 한 줄로 | `ref-spear-jangsu.png` + `ref-growth-bodies.png` (+ 앞에서 뽑은 다른 병과 A가 있으면 함께) |
| B1 · B2 | **장수 눈 감음 · 장수 공격** (한 장에 한 마리) | Claude가 A에서 잘라 준 장수 그림 |

- 창병부터 시작해서 궁병 → 포수 → 기병 → 수군 → 술사 순서로, **같은 대화창**에서 뽑으세요. 앞 병과 결과를 계속 첨부하면 그림체와 크기가 맞습니다.
- 각 블록 안의 **영어만** 복사해서 붙여 넣으세요.

## 성장 규칙 (A에 들어감)

| 등급 | 크기 | 몸 | 머리쓰개 · 옷 |
|---|---|---|---|
| 군졸 | 가장 작음 (장수의 약 70%) | 작고 동글동글한 아기 물방울 | 검은 전립 · 흰 무명 띠 |
| 정병 | 약 80% | 배가 둥글게 차오름 | 붉은 상모 전립 · 남색 허리띠 |
| 군관 | 약 90% | 탄탄한 서양배 모양, 옆에 작은 손 | 강철 투구 · 징 박힌 갑옷띠 |
| 장수 | 100% | 당당한 서양배 모양, 양옆에 작은 젤리 손 | 장수 투구 · 붉은 갑옷 |

---

## A. 성장 라인업 (병과마다 1장)

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Match the attached slime characters exactly: same cute glossy translucent jelly style, soft painted shading, light from the top-left, soft dark outline. The attached growth sheet shows how the body grows.
Draw FOUR slime soldiers of the same unit type standing in one row from left to right, growing up rank by rank, all facing RIGHT in a 3/4 view, with clear empty space between them:
Unit type: {BRANCH}. Jelly body color: {COLOR}. Weapon: {WEAPON}. {GEAR}

1. Rank 1 (smallest, about 70% the size of rank 4): a tiny round baby jelly droplet. Wears a Joseon black felt jeollip hat (a low rounded crown with a very wide flat brim, NOT a top hat, NOT a fedora) and a plain white cotton sash.
2. Rank 2 (about 80%): a bit bigger with a rounder belly. Wears the same jeollip hat with a red feather plume and red band, and a navy cloth belt with a small gold buckle.
3. Rank 3 (about 90%): a firmer pear shape with a small jelly hand. Wears a plain dark steel helmet with a small red tassel and a dark grey armor band with silver studs.
4. Rank 4 (the general, 100%): a confident pear shape with two small stubby jelly hands. Wears a steel general's helmet with a gold brim and a big red feather plume, and a red padded armor plate with gold studs.

The hats and helmets must be WORN: pulled down snugly onto the jelly head, the jelly slightly bulging around the rim, never floating or perched on top. Belts wrap around the body and press slightly into the jelly.
Each slime has big glossy eyes, small determined eyebrows, rosy cheeks and a small mouth, and holds its weapon with a small jelly hand.
No legs. Solid flat magenta background (#FF00FF). No floor, no shadow, no text, no labels.
```

> **확인할 것:** 크기가 확실히 차이 나는지, 모자가 쓰여 있는지(떠 있지 않은지), 네 마리가 겹치지 않는지, 모두 오른쪽을 보는지, **무기가 그림 끝에서 잘리지 않았는지, 군졸도 무기를 들었는지**.

---

## B. 장수 포즈 — 한 장에 한 마리씩 (병과마다 2장)

세 포즈를 한 장에 그리게 하면 제미나이가 고쳐 달라는 부분을 무시하고 같은 그림을 다시 내는 경우가 많아서, **장수 한 마리만 잘라 낸 그림**을 첨부하고 한 장씩 요청합니다. 잘라 낸 그림은 A를 받은 뒤 Claude가 만들어 드립니다 (`<병과>-jangsu-input.png`).

**B1 — 눈 감음**
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.
Redraw the attached slime character exactly as it is — same size, position, pose, helmet, armor and weapon, identical in every detail — except the eyes are closed (blinking). Keep the solid flat magenta background (#FF00FF). Only this one character.
```

**B2 — 공격**
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.
Draw the attached slime character (same design, colors, helmet, armor and weapon) in an attack pose: {ATTACK POSE}, leaning forward with the jelly body stretched toward the target, eyes squeezed and mouth open shouting.
Only this one character, centered with plenty of empty space on every side; the whole weapon must be inside the image. Solid flat magenta background (#FF00FF). No effects, no shadow.
```

---

## 병과별 빈칸 (영어 그대로)

| 병과 | `{BRANCH}` | `{COLOR}` | `{WEAPON}` | `{GEAR}` | `{ATTACK POSE}` |
|---|---|---|---|---|---|
| 창병 | `spear infantry` | `crimson red` | `a long spear with a steel leaf-shaped blade and a red tassel, held pointing up and forward` | (비움) | `thrusting the spear forward with both little jelly hands` |
| 궁병 | `archers` | `forest green` | `a Korean recurve horn bow with tips curling backward` | `A quiver of white-feathered arrows on its back.` | `drawing the bow fully with an arrow nocked, aiming forward` |
| 포수 | `gunners` | `royal purple` | `a short bronze hand cannon on a wooden pole with three gold bands, held at the side` | `A small gunpowder pouch at its waist.` | `aiming the hand cannon straight forward, bracing for the recoil` |
| 기병 | `cavalry` | `ochre gold` | `a flail with a long wooden handle, a short iron chain and a short wooden striker` | `Each slime rides a cute chubby dark-brown chibi pony with a small saddle (the pony is the same size for all ranks; only the slime grows).` | `rearing the pony slightly and swinging the flail down forward` |
| 수군 | `navy sailors` | `ocean blue` | `a single-edged curved Korean hwando sword, not a katana, held blade-up` | `A small wooden oar carried on its back.` | `slashing the sword forward in a wide arc` |
| 술사 | `mystics` | `slate grey` | `a wooden staff topped with a gold ring and two small bells` | `A string of brown prayer beads around its body and a yellow paper talisman with red brush marks (no readable letters).` | `raising the staff high and holding the talisman forward, casting a spell` |

> **기병은 말끼리 겹쳐 나와서 자를 수 없으니, 등급마다 한 장씩(총 4장)** 받으세요. 라인업을 한 번 뽑은 뒤 그 그림을 첨부해 "draw ONLY the rank N rider ... alone"으로 요청하면 그림체가 유지됩니다.

---

## 뽑은 뒤 Claude에게

병과별로 A, B 두 장을 올리고:

> **"창병 라인업 추출해줘"**

여러 병과를 한꺼번에 올려도 됩니다 ("창병·궁병 라인업 추출해줘"). 여섯 병과를 다 모아서 **"유닛 24종 만들어줘"** 라고 해도 됩니다.

### Claude가 하는 일
- 배경·워터마크 제거, 한 마리씩 자르기, 등급별 크기 맞추기 (보드 높이: 군졸 46 · 정병 54 · 군관 60 · 장수 66px, 기병은 말 포함 높이)
- 애니메이션 (그림 한 장 전체를 말랑하게 변형)
  - 대기 4 (모든 등급): 숨쉬듯 눌렸다 늘어남 · 장수는 B의 눈 감은 그림으로 깜빡임
  - 걷기 4 (군졸~군관): 통통 뛰기, 착지할 때 납작 · 기병은 말이 들썩이는 걸음
  - 공격 6 (장수): 기본 → 웅크림 → B의 공격 그림으로 늘어나며 공격 → 되돌아옴, 타격점·발사 지점 JSON
  - 승급 3: 한 등급 위 그림으로 "뽕" 하고 커지는 연출
- 장수 발밑 병과 색 받침, @2x 시트·JSON, 맵 위 미리보기, Git PR
