# 말랑영웅전 (Mallang Heroes)

한국 위인 랜덤 디펜스 — Flutter + Flame, 가로 화면 모바일 게임.

- 웹 미리보기: https://mallang-heroes.github.io
- 안드로이드 APK: https://mallang-heroes.github.io/mallang-heroes.apk

`main`에 올리면 GitHub Actions가 웹과 APK를 빌드해 GitHub Pages에 배포한다.
`android/`, `ios/` 폴더는 저장소에 두지 않고 빌드할 때 `flutter create`로 만든다.

## 구조
세로 화면(폰 390×844 기준). 위쪽은 맵(Flame), 아래쪽은 트레이(Flutter).
- `lib/game/board.dart` — 보드 좌표(585×834), 구불길 경로, 배치 칸 25개(1층 1×5, 2·3층 2×5), 장식 자리
- `lib/game/rules.dart` — 기획표 수치(라운드, 체력, 방어력, 병과 능력치, 은냥·뽑기, 궁 체력)
- `lib/game/map_layer.dart` — 맵 그림(풀밭 + 코드로 그린 길·칸 + 장식), 동굴, 궁
- `lib/game/monster.dart`, `units.dart` — 몬스터(궁에 닿으면 궁 체력 −1, 보스는 즉시 패배), 막사 데이터, 맵 유닛, 투사체
- `lib/ui/overlays.dart` — 위쪽 정보줄, 아래 트레이(막사·강화·유물·효과 탭 + 뽑기), 상세 창, 결과 창
