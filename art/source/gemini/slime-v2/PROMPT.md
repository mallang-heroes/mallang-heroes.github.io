# 제미나이 새 슬라임 프롬프트 — 창병 4종 + 공격 모션 파츠

> **새 슬라임 기준(2026-11-12 확정):** 옆으로 넓은 떡 모양 돔, 맑은 체리 빨강, 큰 하이라이트, 얇은 외곽선. 자세는 **두 손으로 창을 앞으로 겨눈 모습**(창끝 오른쪽, 약 20° 위)으로 4종 통일.
> 기준 그림: 저장소 `art/source/gemini/slime-v2/ref-dome-spear.png`.
> **군졸 = 모자 없는 기본 슬라임(기준 그림 그대로)** — 사용자 결정. 정병·군관·장수는 기준 그림에 모자·갑옷만 얹어 한 장에 한 마리씩 뽑음.
> 4종을 한 장에 뽑으면 제미나이가 앞 그림을 고쳐 그리는 쪽으로 가서 망가짐 → **한 마리씩, 새 대화창에서**.
> 자른 결과: `spear-r1~r4-cut.png`, 미리보기: `art/preview/slime-v2/` (`spear-lineup.png`, `spear-on-spring-map.png`). 자르기 스크립트 `art/tools/slime/cut_v2.py`.

---

## ① 등급 그림 (한 장에 한 마리, 새 대화창) — 완료

**장수** (첨부: `ref-dome-spear.png`)
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Redraw the attached slime exactly as it is: the same size, the same low wide dome body, the same bright glossy cherry red jelly, the same big highlight, the same thin outline, the same face, and the same pose with two small round jelly hands holding the spear across the front of the body pointing to the right. Do not change the body shape, the pose or the spear.
Only add: a steel general's helmet with a gold brim and a red feather plume, worn snugly on top of the jelly dome (the jelly slightly bulging around the rim), and a small red armor plate with gold studs on the lower front of the body, partly behind the spear.
Only this one character, centered. Solid flat magenta background (#FF00FF). No shadow, no text.
```

**군관 / 정병** (첨부: `ref-dome-spear.png` + 장수)
```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Redraw the first attached slime exactly as it is — same size, same dome body, colors, outline and the same two-handed spear pose — in the same style as the second attached image.
Only add: {GEAR}
Only this one character, centered. Solid flat magenta background (#FF00FF). No shadow, no text.
```
- 군관 `{GEAR}`: `a plain dark steel helmet with a small red tassel on top, worn snugly on the jelly dome, and a dark grey armor band with silver studs wrapped around the lower body, pressing slightly into the jelly. Face: calm but determined, small eyebrows.`
- 정병 `{GEAR}`: `a black Joseon felt jeollip hat (low rounded crown, wide flat brim) with a red feather plume and a red band, worn snugly on the jelly dome, and a navy cloth belt with a small gold buckle around the lower body. Face: cute and a little serious, no frown.`

---

## ② 몸 / 두 손+창 분리 — Claude가 직접 (제미나이 안 씀)

제미나이에게 분리를 맡겼더니 한 손이 몸에 붙어 남고 창 각도가 바뀌어서(시도 `spear-r1-parts-try1.png`), **원본 그림에서 Claude가 두 손+창을 직접 떼고 몸 빈자리를 메움**. 스크립트 `art/tools/slime/split_spear_v2.py` (좌표 `spear-rig.json`). 창이 창대 방향으로만 움직여서, 몸에서 드러나는 곳은 손 자리 정도라 메운 자국이 거의 안 보임.

## ③ (선택) 공격 얼굴 · 눈 감음 — 첨부: `spear-rN-body.png`

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Redraw the attached slime body twice, side by side, exactly the same size, shape, hat, belt and colors, identical in every detail except the face:
1. Attack face: eyes squeezed shut in determined arcs, eyebrows angled down, mouth wide open shouting.
2. Blink: the normal face with the eyes closed as two small curved lines.
Solid flat magenta background (#FF00FF). No shadow, no text.
```

---

## Claude에게 할 말 / Claude가 하는 일

| 할 말 | 하는 일 |
|---|---|
| (완료) 창병 리깅 | `art/tools/slime/build_spear_v2.py` → `art/out/slime-v2/spear-rN.png/json`, 미리보기 `spear-anim.gif`·`spear-on-spring-map.png`. 맵 배치는 **무기 제외 몸 가운데**를 칸 가운데에(앵커 = 몸 발밑 가운데) |

**애니메이션 (계획)**
- 대기 4프레임(6fps): 몸이 숨쉬듯 눌렸다 늘어남, 두 손+창은 몸을 따라 살짝 오르내림, 가끔 눈 깜빡임.
- 공격 6프레임(12fps): 기본 → 준비(몸이 뒤로 눌리고 두 손+창을 창대 방향으로 뒤로 당김) → 찌르기 2(공격 얼굴, 몸이 앞으로 늘어나고 **두 손+창이 창대 방향으로 쭉 뻗어 창끝이 먼저 나감**) → 멈칫 → 복귀. 손은 창의 같은 자리를 계속 쥠.
- JSON `events.hit` = 찌르기 프레임의 창끝 위치. 왼쪽은 좌우 반전.

---

# 궁병 (2026-11-12 완료)

순서: ① 군졸 = `ref-dome-spear.png`를 첨부해 연두색·각궁·화살 메긴 자세로 → ② 정병~장수 = 궁병 군졸 + 같은 등급 창병 그림을 첨부해 모자·띠만 얹음 → ③ **깨끗한 몸** = 등급 그림을 첨부해 "화살·시위·왼쪽 손만 지우고 활과 오른팔은 그대로" (군졸은 "no hat, no belt"를 꼭 넣을 것 — 안 넣으면 새싹 모자·띠를 지어 붙임).

리깅: 몸(활·앞팔 포함) / 시위(코드로 그림) / 뒷손 / 화살. 화살·뒷손은 원본에서 Claude가 직접 떼고(`split_archer_v2.py`), 공격은 화살 축 뒤로 당김 → 쏨(화살은 투사체 `archer-arrow.png`, JSON `events.projectile` = 프레임 3의 화살촉 위치·각도) → 시위 떨림 → 다시 메김 (`build_archer_v2.py`). 군졸 깨끗한 몸에 남은 뒷손은 스크립트가 지움.
