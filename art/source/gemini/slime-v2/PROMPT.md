# 제미나이 새 슬라임 프롬프트 — 창병 4종 + 공격 모션 파츠

> 계절 맵과 같이 뽑은 **새 슬라임 느낌**(단순한 광택 젤리, 점 눈, 볼터치, 작은 무기)으로 기본 슬라임을 다시 뽑습니다. 창병부터.
> 공격은 **몸이 튀어나가는 방식이 아니라 창끝으로 찌르는 모션**이라, 몸과 "창 쥔 손"을 따로 받아 Claude가 리깅합니다. 창은 그림에 그려진 손 하나로만 쥐고, 손을 바꿔 쥐지 않습니다.
>
> 참고 그림(저장소 `art/source/gemini/slime-v2/`): `ref-new-spear.png`(빨간 창 슬라임), `ref-new-slimes.png`(새 슬라임 5마리).
> 모두 **같은 대화창**에서 뽑고, 영어 블록만 복사하세요.

| 순서 | 뽑을 것 | 첨부 | 장 수 |
|---|---|---|---|
| ① | 창병 성장 라인업 (군졸·정병·군관·장수) | `ref-new-spear.png` + `ref-new-slimes.png` | 1장 |
| ② | 등급별 파츠: 몸(손·창 없음) + 창 쥔 손 | Claude가 ①에서 잘라 준 등급 그림 1장 | 등급마다 1장 (4장) |
| ③ | 등급별 공격 얼굴 몸 | ②에서 받은 몸 | 등급마다 1장 (4장) |

---

## ① 창병 성장 라인업

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Match the attached slime characters exactly: the same simple, cute, glossy jelly style with a soft highlight on top, soft dark-brown outline, small black dot eyes, a tiny mouth, pink blush cheeks, soft painted shading with light from the top-left. Keep them simple and round like the attached ones, not detailed.

Draw FOUR red slime spear soldiers standing in one row from left to right, growing up rank by rank, all facing the viewer with the eyes glancing slightly to the right, with clear empty space between them. Jelly body color: bright crimson red.

1. Rank 1 (smallest, about 70% the height of rank 4): a tiny round baby jelly drop. Wears a small black Joseon felt jeollip hat (low rounded crown with a wide flat brim) and a plain white cloth sash.
2. Rank 2 (about 80%): a bit bigger and rounder. Wears the same jeollip hat with a red feather plume, and a navy cloth belt with a small gold buckle.
3. Rank 3 (about 90%): a firmer, slightly taller drop. Wears a plain dark steel helmet with a small red tassel and a dark grey armor band with silver studs.
4. Rank 4 (the general, 100%): a proud, slightly taller drop. Wears a steel general's helmet with a gold brim and a red feather plume, and a small red armor plate with gold studs. No cape.

Hats and helmets are WORN, pulled down snugly onto the jelly, never floating. Belts press slightly into the jelly.

Every slime has ONE small round jelly hand on its right side (the viewer's right), and that hand holds a spear: a straight wooden shaft with a steel leaf-shaped blade and a small red tassel. The spear is held at the middle of the shaft, tilted forward so the blade points up and to the RIGHT at about 45 degrees, the blade well away from the body. The spear grows a little with each rank. The whole spear must be inside the image.
No other hands, no legs.
Solid flat magenta background (#FF00FF). No floor, no shadow, no text, no labels.
```

**확인할 것:** 네 마리 크기 차이가 분명한지, 모두 **손 하나로 창 가운데를 쥐고 창끝이 오른쪽 위**를 향하는지, 창이 잘리지 않았는지, 모자가 떠 있지 않은지. → Claude에게 **"창병 라인업 잘라줘"** 하면 ②에 넣을 등급별 그림을 만들어 드립니다.

---

## ② 등급별 파츠 (등급마다 1장, 4번)

Claude가 잘라 준 `spear-r1-input.png` ~ `spear-r4-input.png`를 하나씩 첨부.

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Split the attached slime character into TWO separate pieces drawn side by side, with wide empty space between them, at exactly the same size, colors and style as the attached image:

LEFT piece: the slime body only — same body, face, hat and belt — but WITHOUT the spear and WITHOUT the hand that holds it. Where the hand was, the jelly body is smooth and complete.
RIGHT piece: only the small round jelly hand gripping the spear, exactly the same size and the same 45-degree angle as in the attached image, with the whole spear shaft and blade complete (also the part that was hidden behind the hand).

Solid flat magenta background (#FF00FF). No shadow, no floor, no text.
```

**확인할 것:** 몸 쪽에 손·창 자국이 남지 않았는지, 창이 원래와 같은 각도·길이인지. 창이 끊겨 나오면 "the spear must be one complete straight piece"를 붙여 다시.

---

## ③ 공격 얼굴 (등급마다 1장, 4번)

②에서 받은 그림을 첨부.

```
Generate an image. Do not write any words, letters or numbers anywhere in the image.

Redraw ONLY the left piece (the slime body without the spear) of the attached image, exactly the same size, shape, hat, belt and colors, identical in every detail — except the face: eyes squeezed shut in determined arcs (> <), small eyebrows angled down, and the mouth wide open shouting.
Next to it, draw the same body once more with the normal face but the eyes closed (a blink: two small curved lines).
Solid flat magenta background (#FF00FF). No shadow, no text.
```

---

## Claude에게 할 말 / Claude가 하는 일

| 할 말 | 하는 일 |
|---|---|
| **"창병 라인업 잘라줘"** + ① | 배경·워터마크 제거, 한 마리씩 자르기 → ②용 `spear-r1~r4-input.png` |
| **"창병 리깅해줘"** + ②·③ 8장 | 몸·손+창 분리 저장, 등급별 크기 맞춤(칸 63×63 안에 장수까지 들어가게), 손이 창을 쥐는 점·창끝 좌표 잡기 → 애니메이션 → 시트·JSON → 맵 위 미리보기(봄 맵) |

**애니메이션 (계획)**
- 대기 4프레임(6fps): 몸이 숨쉬듯 눌렸다 늘어남, 손+창은 몸을 따라 살짝 오르내림, 가끔 눈 깜빡임.
- 공격 6프레임(12fps): ① 기본 → ② 준비(몸이 뒤로 눌리고 손+창을 창대 방향으로 뒤로 당김) → ③④ 찌르기(공격 얼굴, 몸이 앞으로 늘어나고 **손+창이 창대 방향으로 쭉 뻗어 창끝이 먼저 나감**) → ⑤ 멈칫 → ⑥ 복귀. 손은 창의 같은 자리를 계속 쥠.
- JSON `events.hit` = 찌르기 프레임의 창끝 위치. 왼쪽은 좌우 반전.
