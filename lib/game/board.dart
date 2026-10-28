import 'dart:math' as math;
import 'dart:ui';

/// 보드 좌표 (세로 화면, 기준 해상도 585×834 = 폰 390×556pt의 1.5배).
/// 맵은 화면 위쪽, 아래쪽은 Flutter 트레이(막사·강화·유물·효과 + 뽑기)가 차지한다.
class Board {
  static const double width = 585;
  static const double height = 834;

  static const List<Branch> branches = [
    Branch('창병', 'spear', Color(0xFF9A3B2E)),
    Branch('궁병', 'archer', Color(0xFF3F6B3A)),
    Branch('포수', 'gunner', Color(0xFF5E4E8C)),
    Branch('기병', 'cavalry', Color(0xFF8A6418)),
    Branch('수군', 'navy', Color(0xFF2E5E8C)),
    Branch('술사', 'mystic', Color(0xFF4A4E54)),
  ];

  static Branch branch(String name) => branches.firstWhere((b) => b.name == name);

  /// 단계별 몬스터 이동 속도 (px/s). 1–10R, 11–20R, ...
  /// 몬스터 사이 거리 = 속도 × 나오는 간격(1초) → 60px 이상이라 겹치지 않음. (예전 30~48의 2배)
  static const List<double> stageSpeed = [60, 66, 72, 80, 88, 96];
  static double speedForRound(int round) =>
      stageSpeed[math.min((math.max(round, 1) - 1) ~/ 10, stageSpeed.length - 1)];
}

class Branch {
  final String name;
  final String key; // 그림 파일 이름에 쓰는 영문 키
  final Color color;
  const Branch(this.name, this.key, this.color);
}

/// 장식 하나: 종류(map-prop-<kind>.webp)와 바닥 가운데.
class Deco {
  final String kind;
  final Offset foot;
  const Deco(this.kind, this.foot);
}

/// 세로 맵 배치: 오른쪽 아래 동굴 → 3층 구불길 → 맨 위 궁.
/// 배치 칸은 1층(동굴 바로 앞) 1×5, 2·3층 2×5 (모두 25칸).
class MapData {
  /// 길 폭 (흙길 바깥 테두리까지).
  static const double roadWidth = 60;

  /// 몬스터가 걷는 길 중심선 (동굴 입구 → 궁 문).
  static const List<Offset> path = [
    Offset(560, 792),
    Offset(66, 792),
    Offset(66, 660),
    Offset(519, 660),
    Offset(519, 459),
    Offset(66, 459),
    Offset(66, 258),
    Offset(292.5, 258),
    Offset(292.5, 232),
  ];

  /// 동굴 그림의 바닥 가운데.
  static const Offset cave = Offset(540, 800);

  /// 궁 그림의 바닥 가운데 (궁 그림 약 141×122).
  static const Offset palace = Offset(292.5, 240);

  /// 배치 칸 크기와 간격.
  static const double tile = 63;
  static const double pitch = 69;
  static const List<double> _cols = [154.5, 223.5, 292.5, 361.5, 430.5];
  static const List<double> _rows = [726, 594, 525, 393, 324]; // 1층, 2층(아래·위), 3층(아래·위)

  /// 칸 가운데 목록. 앞(동굴 가까운 1층)부터.
  static final List<Offset> tiles = [
    for (final y in _rows)
      for (final x in _cols) Offset(x, y),
  ];

  /// 칸 위에 선 유닛의 발 위치 (칸 가운데보다 살짝 아래).
  static Offset footOf(int tileIndex) => tiles[tileIndex].translate(0, 14);

  /// 막사 문: 트레이 쪽(맵 아래 끝). 막사로 들어가는 유닛이 여기로 걸어가고, 꺼낸 유닛이 여기서 나온다.
  static Offset barracksDoor(String branch) {
    final i = Board.branches.indexWhere((b) => b.name == branch);
    return Offset(100 + i * 77, Board.height + 30);
  }

  static const List<Deco> decorations = [
    Deco('tree-zelkova', Offset(452, 192)),
    Deco('pine-a', Offset(546, 206)),
    Deco('pine-b', Offset(56, 196)),
    Deco('pine-a', Offset(150, 206)),
    Deco('rock-a', Offset(568, 384)),
    Deco('bush', Offset(566, 560)),
    Deco('tuft-a', Offset(18, 556)),
    Deco('flowers-yellow', Offset(20, 380)),
  ];
}

/// 꺾은선 하나를 길이로 따라가는 도구.
class _Polyline {
  _Polyline(this.pts) {
    acc.add(0);
    for (var i = 1; i < pts.length; i++) {
      acc.add(acc.last + (pts[i] - pts[i - 1]).distance);
    }
  }

  final List<Offset> pts;
  final List<double> acc = [];
  double get length => acc.last;

  int _seg(double s) {
    var lo = 0, hi = acc.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (acc[mid] <= s) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  Offset at(double s) {
    s = s.clamp(0, length);
    final i = _seg(s);
    final a = pts[i];
    final b = pts[i + 1];
    final segLen = acc[i + 1] - acc[i];
    final t = segLen == 0 ? 0.0 : (s - acc[i]) / segLen;
    return Offset.lerp(a, b, t)!;
  }

  Offset dir(double s) {
    s = s.clamp(0, length);
    final i = _seg(s);
    final d = pts[i + 1] - pts[i];
    return d.distance == 0 ? const Offset(1, 0) : d / d.distance;
  }
}

/// 몬스터 이동 경로: 동굴에서 나와 구불길을 따라 궁까지 간다.
class RoadTrack {
  RoadTrack() : _line = _Polyline(MapData.path);

  final _Polyline _line;

  double get length => _line.length;
  Offset positionAt(double s) => _line.at(s);
  Offset directionAt(double s) => _line.dir(s);
}
