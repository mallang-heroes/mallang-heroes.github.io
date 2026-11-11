# 말랑영웅전 — 유니티 프로젝트

> 2026-11-11부터 엔진을 Flutter + Flame에서 **Unity 6 (6000.x LTS)** 로 옮긴다.
> 저장소는 그대로 쓰고, 유니티 프로젝트는 이 `unity/` 폴더에 둔다. Flutter 코드(`lib/`)는 옮기는 동안 참고용으로 남겨 둔다.

## 여는 법
1. Unity Hub → **Add project from disk** → 이 저장소의 `unity` 폴더 선택.
2. 에디터는 **Unity 6.6 (6000.6.7f1)** 기준. 다른 Unity 6 버전이어도 열린다.
3. 처음 열 때 `Library/`를 만드느라 몇 분 걸린다. 씬은 따로 열지 않아도 된다 — 새로 생긴 빈 씬에서 **▶(Play)** 를 누르면 `PreviewBootstrap`이 자동으로 실행된다.
4. Game 창 해상도는 세로 비율(예: **1170×2532** 또는 9:19.5)로 맞춰서 본다.

▶ 하면 보여야 하는 것 (1단계 확인, 실제 화면: `art/preview/unity-step1.jpg`):
- 도트 세로 맵 (바닥 + 궁 + 동굴 입구 반짝임)
- 배치 칸 20곳에 창병·궁병·포수 도트 슬라임 (군졸~장수), 살짝 말랑거림
- 동굴 입구에서 1초마다 나와 길 두 줄로 궁까지 걷는 동그라미 (몬스터 자리표시)

이상한 점(그림이 흐림·위치 어긋남·빨간 오류)이 있으면 Console 창 오류와 화면을 캡처해서 보내 주면 된다.

## 구조
| 경로 | 내용 |
|---|---|
| `Assets/Resources/Art/` | 그림. **직접 고치지 말고** `python3 art/tools/unity/sync_art.py`로 다시 만든다 |
| `Assets/Scripts/Editor/PixelArtImporter.cs` | Art 그림을 도트용(Point, 압축 없음)으로 가져오기 |
| `Assets/Scripts/Game/Rules.cs` | 기획 수치 (Flutter `rules.dart` 그대로) |
| `Assets/Scripts/Game/Board.cs` | 보드 좌표 585×834, 길·배치 칸, 경로 따라가기 (`board.dart`) |
| `Assets/Scripts/Game/Layout.cs` | `layout.json` 읽기 (궁·동굴 자리, 슬라임 발 위치) |
| `Assets/Scripts/Game/Sprites.cs` | 그림 → 스프라이트 (피벗 = 발) |
| `Assets/Scripts/Game/MapView.cs`, `SlimeView.cs`, `MobPlaceholder.cs` | 맵·슬라임·자리표시 몬스터 |
| `Assets/Scripts/Game/PreviewBootstrap.cs` | 1단계 확인용 시작점 |

좌표 약속: 게임 로직은 **보드 좌표**(왼쪽 위 0,0, 아래로 y 증가, Flutter와 같음)로 계산하고, 그릴 때만 `Board.ToWorld`로 바꾼다 (보드 100 = 월드 1).
그림 크기: 맵 그림은 @2x(보드 1 = 2px), 도트 유닛은 1도트 = 보드 2.
앞뒤 순서: `Board.SortOrder(발 y)` — 아래쪽에 선 것이 앞.

## 옮기는 순서
| 단계 | 내용 | Flutter 원본 |
|---|---|---|
| 1 ✅ | 프로젝트 뼈대, 도트 맵·슬라임 표시, 길 경로 확인 | `board.dart`, `map_layer.dart`, `rules.dart` |
| 2 | 라운드 진행·몬스터 생성/이동/궁 체력·패배 | `mallang_game.dart`, `monster.dart` |
| 3 | 유닛 공격·사거리·피해·치명·광역, 합성(같은 병과·등급 3 → 다음 등급), 판매 | `units.dart`, `effects.dart` |
| 4 | 아래 트레이 UI(막사·강화·유물·효과 탭, 뽑기·무료 뽑기권, 은냥), 위 정보줄 | `overlays.dart`, `hud.dart` |
| 5 | 터치 조작(칸 옮기기·막사 넣기/꺼내기), 저장 | `overlays.dart`, `mallang_game.dart` |
| 6 | 안드로이드·iOS 빌드 설정 | — |

남은 그림(궁병 색 결정, 기병·수군·술사 슬라임, 몬스터, UI 도트 스킨)은 나오는 대로 `sync_art.py`로 넣는다.
