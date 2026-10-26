# 한국 위인 랜덤디펜스 — 캐릭터 모델링 프롬프트 (군졸~장수)

> 다른 도구·세션에서 캐릭터만 뽑아볼 때 쓰는 프롬프트입니다.
> **A. 작업 지시문**은 코드(SVG)로 그리는 AI(Claude 등)에, **B. 이미지 생성용 짧은 프롬프트**는 그림 생성 AI에 붙여 넣으세요.

---

## A. 작업 지시문 (그대로 붙여 넣기)

너는 모바일 가로형 랜덤 디펜스 게임 「한국 위인 랜덤디펜스」의 캐릭터 디자이너다. 아래 규칙대로 **창병 장수 1명**을 세 가지 콘셉트(귀여운 장수 · 슬라임 · 메카)로 그려라. 결과를 보여 주고 내가 고르면 나머지 병과·등급으로 확장한다.

### 1. 게임과 크기
- 한국사 위인이 유닛인 디펜스. 유닛은 길 옆에 서서 지나가는 몬스터를 공격한다.
- 화면 기준: 게임 보드 1560×720px = 폰 가로 화면 844×390pt (약 1.85배).
- 유닛 프레임(보드 기준): 군졸·정병·군관 62×72, 장수 72×84. **기병은 말 탄 모습**으로 막사 유닛 80×72, 장수 96×84.
- 폰에서 유닛은 약 40~45pt로 보인다. 이 크기에서 **병과(무기)와 등급(옷·모자·받침)** 이 한눈에 구분돼야 한다.
- 모든 캐릭터는 **오른쪽을 본다.** 왼쪽은 게임에서 좌우 반전으로 쓴다(반전돼도 어색하지 않게 글자·좌우 비대칭 문양은 피한다).
- 배경 투명, 앵커는 **하단 중앙**(발밑, 기병은 말 발굽 사이).

### 2. 그림체 (모든 콘셉트 공통)
- 2단 셀 셰이딩: 기본색 + 그늘색(기본색 명도 ×0.72). **광원은 왼쪽 위**, 그늘은 오른쪽 아래 테두리.
- 외곽선 1.8px(보드 기준), 색 `#2A211C`. 작은 장식은 0.7~1.0px.
- **원·사각형을 이어 붙인 느낌 금지.** 얼굴·몸·팔은 곡선 실루엣으로 직접 그린다.
  - 얼굴: 볼이 통통하고 턱으로 모이는 3/4 얼굴형, 옆머리와 귀
  - 눈: 세로로 긴 검은 눈 + 하이라이트 2개, 눈꺼풀 선, 끝이 가는 굵은 눈썹(용맹한 표정), 볼터치, 작은 입
  - 몸: 어깨가 흘러내리고 아래로 퍼지는 옷, 몸 곡선을 따라 휘는 허리띠·징 줄, 옷 주름 1~2줄
  - 팔: 어깨에서 손으로 갈수록 가늘어지는 소매(팔꿈치 굽음), 무기를 감싸 쥔 손. 뒷팔은 몸 뒤로 넘기고 무기를 쥔 손만 보이게
- 공통 색: 피부 `#E9BC93`, 투구 `#5A606A`, 금장식 `#D4AE50`, 상모·술 `#C9402F`, 드림·옷깃 `#33404E`, 허리띠·장화 `#3A302A`, 징 `#F0C95A`

### 3. 병과 (색 · 무기 · 등 장비)
| 병과 | 색 | 앞손 무기 | 등·허리 |
|---|---|---|---|
| 창병 | `#9A3B2E` | 장창 (붉은 술) | — |
| 궁병 | `#3F6B3A` | 각궁 (양끝이 뒤로 휜 고자, 굵게) | 동개(화살통), 화살 깃이 어깨 위로 |
| 포수 | `#5E4E8C` | 자루 달린 총통 (쇠 띠 3개) | 허리 뒤 화약 주머니·화승 |
| 기병 | `#8A6418` | 편곤 (자루 + 쇠사슬 + 타격봉), 말 탄 모습 | 안장 언치가 병과 색, 말은 짙은 갈색 |
| 수군 | `#2E5E8C` | 환도 (날을 위로) | 등에 멘 노(넓은 노깃이 어깨 위로) |
| 술사 | `#4A4E54` | 고리·방울 달린 지팡이 | 뒷손 부적, 목에 염주. 옷은 밝은 회색 `#8C9097` + 먹색 테두리 |

### 4. 등급 표시
| 등급 | 옷 | 모자 | 표시 |
|---|---|---|---|
| 군졸 | 흰 무명옷 | 전립(넓은 챙) | — |
| 정병 | 병과 색 군복 | 전립 + 붉은 상모 | — |
| 군관 | 어두운 갑주 `#474C55` + 은 징 | 투구 | 무기에 붉은 술 |
| 장수 | 병과 색 두정갑 + 금 징 | 투구 + 상모 | 발밑 병과 색 받침 원 |

### 5. 세 가지 콘셉트 (창병 장수로 각각 1장)
1. **귀여운 장수 (약 2~2.5등신)**: 머리가 프레임 높이의 45% 안팎. 둥근 투구와 목을 감싼 드림, 짧고 통통한 두정갑, 뭉툭한 장화, 몸보다 큰 창. 귀엽지만 눈썹으로 용맹함을 남긴다.
2. **슬라임**: 병과 색의 말랑한 반투명 젤리 몸(윤기 반사광, 기포, 아래쪽 밝은 테두리). 투구를 비스듬히 얹고, 징 박힌 허리띠로 장수 표시. 얼굴은 1번과 같은 눈·눈썹·볼. 무기는 몸에서 늘어난 젤리 손으로 쥔다.
3. **메카(로봇)**: 조선 투구와 두정갑을 기계 장갑으로 옮긴 **오리지널** 디자인. 특정 작품의 얼굴 마스크·V자 뿔·대표 색 배치는 쓰지 않는다. 투구형 헤드에 빛나는 바이저(`#8BEAF4`), 가슴 코어, 리벳 같은 징이 박힌 허리 장갑판, 큰 어깨 장갑, 등 추진기, 빛나는 에너지 창날. 장갑은 병과 색, 골격은 `#6B717B`, 관절은 `#3A3E45`.

### 6. 애니메이션 (컷아웃 리깅)
- 프레임마다 다시 그리지 않는다. 머리·몸·팔·무기·다리·장식을 **파츠(SVG 그룹)** 로 나누고 회전·이동·늘림으로 움직인다.
- **대기 4프레임 (6fps)**: 숨쉬듯 몸이 살짝 눌렸다 늘어남(가로 1.04·세로 0.96 정도), 상모·술이 한 박자 늦게 흔들림, 3번째 프레임에 눈 깜빡임.
- **공격 6프레임 (12fps)**: ① 준비 ② 웅크리며 뒤로(예비동작) ③ 최대로 당김 ④ 앞으로 늘어나며 공격 + 잔상선·섬광 + 기합 입 ⑤ 살짝 더 나감(따라가기) ⑥ 돌아옴.
  - 병과별 공격: 창 찌르기 / 활 당겨 쏘기 / 총통 수평 조준 후 발사(섬광→연기) / 말 위에서 편곤 내려치기 / 환도 크게 베기(칼바람) / 지팡이에 기운 구슬을 모아 발사
- **걷기 4프레임 (10fps)** — 군졸·정병·군관만: 다리 교차, 걸음마다 몸 들썩임. 기병은 말 다리를 대각선 쌍으로.
- 콘셉트별 추가: 슬라임은 눌림·늘림을 크게(1.15 / 0.85) + 공격 때 젤리 방울. 메카는 대기 때 바이저·코어가 밝아졌다 어두워지고, 공격 때 추진기 불꽃.
- 공격 프레임은 무기가 몸 밖으로 나가므로 **여백을 둔 캔버스**(보병 약 136×92, 기병 약 168×92)를 쓰되 앵커는 대기와 같은 발밑 점.

### 7. 산출물
- 원본 SVG(파츠 그룹 id 정리) + PNG **@2x**(보드 크기의 2배)
- 동작별 스프라이트 시트 PNG + JSON (TexturePacker Hash 호환):
  ```json
  {"frames": {"unit-spear-jangsu-attack-3": {
      "frame": {"x":816,"y":0,"w":272,"h":184}, "duration": 83,
      "anchor": {"x":0.5,"y":1.0},
      "events": {"hit": {"x":250,"y":96}}}},
   "animations": {"attack": ["unit-spear-jangsu-attack-0", "..."]},
   "meta": {"image":"unit-spear-jangsu-attack.png","scale":"2","fps":12}}
  ```
  `events.projectile`(투사체가 나가는 점) / `events.hit`(근접 타격 점)은 해당 프레임에만 넣는다.
- 파일 이름: 영문 소문자 + 하이픈. 예: `unit-spear-jangsu-idle.png`, `unit-archer-gunjol-walk.json`
- 확인용 미리보기: ① 3배 확대 정지 그림 ② 대기·공격 GIF ③ 보드 크기(1:1)와 폰 실제 크기(÷1.85)로 줄여 풀밭(`#B9C59E`) 위에 놓은 그림

### 8. 주의
- 실존 인물·특정 드라마·게임·애니 캐릭터 디자인을 닮게 그리지 않는다.
- 복식·무기는 조선 고증을 따르되, 확실하지 않은 부분은 "고증 확인 필요"로 표시한다.

---

## B. 이미지 생성용 짧은 프롬프트 (영문)

그림 생성 AI용입니다. 결과는 시안 참고용이고, 게임에 넣을 최종본은 A 방식(SVG + 리깅)으로 다시 그립니다.

**공통 꼬리말** (각 프롬프트 뒤에 붙이기)
```
single character, full body, facing right in 3/4 view, game sprite, 2-tone cel shading, light from top-left, clean dark brown outline, flat transparent background, readable at small size, no text, no watermark
```

**1. 귀여운 장수**
```
cute chibi Joseon dynasty Korean spearman general, about 2 heads tall, big round steel helmet with gold brim and red feather plume, dark navy neck guard, short chubby red padded armor coat with gold studs, curved belt, stubby dark boots, large glossy eyes with highlights, thick determined eyebrows, rosy cheeks, holding a long spear with red tassel
```

**2. 슬라임**
```
cute red jelly slime creature wearing a small Joseon Korean steel helmet with red feather plume tilted on its head, translucent glossy body with highlight and bubbles, studded leather belt, big glossy eyes, thick brave eyebrows, rosy cheeks, a stretchy jelly arm holding a long spear with red tassel
```

**3. 메카**
```
original chibi mecha warrior inspired by Joseon Korean armor, helmet-shaped robot head with glowing cyan visor slit and red plume, red armor plates with gold rivets on a gray frame, large shoulder pauldron, glowing chest core, back thruster pack, holding a spear with a glowing cyan energy blade
```

**공통 제외어** (지원하는 도구라면)
```
realistic, photo, 3D render, gore, background scenery, multiple characters, text, logo, V-shaped head fin, face mask with vents
```
