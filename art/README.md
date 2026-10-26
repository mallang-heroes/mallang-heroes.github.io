# 말랑영웅전 그래픽 작업 폴더

그림은 제미나이로 그리고, 자르기·리깅·애니메이션·배치는 `art/tools`의 스크립트로 만든다.
게임에서 쓰는 결과물은 `assets/images`, `assets/data`에 있다.

## 폴더
| 경로 | 내용 |
|---|---|
| `art/source/gemini/` | 제미나이 원본 (맵 4장 + 배치 가이드, 창병 장수 기준 그림·파츠 시트와 잘라 낸 파츠, `monsters/` 몬스터 시안·표정·조각) |
| `art/tools/map/` | `build_map.py` — 배경 정리·길 중심선 추출, 장식·건물·동굴 추출과 배치 |
| `art/tools/monster/` | `build_monsters.py`(몬스터 시안 → 다리·꼬리 리깅, 표정 교체, 걷기·피격·쓰러짐·보스 등장 시트), `preview_road.py`(길 위 걷기 GIF) |
| `art/tools/rig/` | `extract.py`(배경 제거·파츠 분리), `rig_spear.py`(창병 장수 리깅·애니메이션), `preview.py`(미리보기) |
| `art/docs/` | 제미나이 프롬프트(캐릭터·맵), 진행 현황, 이전 프롬프트 |
| `art/preview/` | 확인용 이미지·GIF (게임에는 안 씀) |
| `assets/images/map/` | 배경(@2x 3120×1440), 궁·막사(+들썩임 3프레임), 장식 13종, 출현 동굴(4프레임) |
| `assets/images/units/spear/jangsu/` | 창병 장수 기본·대기 4·공격 6 (@2x 시트 + JSON), 받침 없는 `-nopad` |
| `assets/images/monsters/<이름>/` | 몬스터 12종(mob-/boss- × boar·tiger·gumiho·dokkaebi·ghost, mob-zombie, 최종 보스 boss-zombie-king 96×100): 정지 1장, `-walk`(6)·`-hit`(1)·`-die`(4, 보스 6)·보스 `-appear`(6) @2x 시트 + JSON |
| `assets/data/map-path.json` | 순환로·출현 갈림길 점 목록, 건물 자리·크기, 장식 위치(blocks: 유닛 배치를 막는지) |

## 수치
- 보드 1560×720 (오른쪽 156px 패널). 이미지 파일은 모두 @2x.
- 몬스터 경로: 제미나이 그림에서 추출한 둥근 직사각형 순환로 (길이 약 3055px, 폭 약 58px). 출현 갈림길은 x=1282, 동굴 입구 (1282,104) → 합류 (1282,209), 합류점부터 시계 방향.
- 스프라이트 JSON: TexturePacker Hash 호환 + `anchor`(발밑 비율), `events.hit` / `events.projectile`(@2x 프레임 픽셀). 좌우 반전 시 x' = w − x.
- 몬스터 JSON은 `meta.body`(판정용 보드 크기: 일반 40×44, 보스 72×76)와 `meta.loop`(걷기만 true)을 더 갖는다. 구미호 꼬리는 body 밖으로 넘친다. 피격 프레임은 하얀 번쩍임이 그려져 있다.

## 아직 게임 코드에 연결 안 됨
- `lib/game/board.dart`는 예전 육각형 경로를 코드로 계산한다. 새 맵을 쓰려면 `assets/data/map-path.json`의 점 목록으로 바꿔야 한다.

## 새 소스 추가 흐름
1. `art/docs/gemini-source-prompt.md`(캐릭터) / `gemini-map-prompt.md`(맵)로 제미나이에서 뽑기
2. `art/source/gemini/<이름>/`에 저장
3. 스크립트 실행 → `assets/images`에 결과, `art/preview`에 확인용
(스크립트 안의 일부 경로는 작업 환경 기준이라 실행 위치에 맞게 고쳐 써야 할 수 있다.)
