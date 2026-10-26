# 말랑영웅전 (Mallang Heroes)

한국 위인 랜덤 디펜스 — Flutter + Flame, 가로 화면 모바일 게임.

- 웹 미리보기: https://mallang-heroes.github.io
- 안드로이드 APK: https://mallang-heroes.github.io/mallang-heroes.apk

`main`에 올리면 GitHub Actions가 웹과 APK를 빌드해 GitHub Pages에 배포한다.
`android/`, `ios/` 폴더는 저장소에 두지 않고 빌드할 때 `flutter create`로 만든다.

## 구조
- `lib/game/board.dart` — 보드 좌표(1560×720), 순환로·출현 갈림길 경로
- `lib/game/rules.dart` — 기획표 수치(라운드, 체력, 방어력, 병과 능력치, 보급)
- `lib/game/map_layer.dart` — 맵 그림 (임시, 코드로 그림)
- `lib/game/monster.dart`, `units.dart` — 몬스터, 막사, 장수, 투사체
- `lib/game/hud.dart`, `lib/ui/overlays.dart` — 오른쪽 패널, 막사 창, 결과 창
