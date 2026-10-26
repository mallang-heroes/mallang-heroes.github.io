import 'dart:math' as math;
import 'dart:ui';

/// 보드 좌표 (기준 해상도 1560×720, 오른쪽 156px은 패널).
class Board {
  static const double width = 1560;
  static const double height = 720;
  static const double playWidth = 1404;

  static const double cx = 702;
  static const double cy = 360;
  static const double yT = 120;
  static const double yB = 600;
  static const double xPL = 54;
  static const double xPR = 1350;
  static const double cornerRadius = 110;

  /// 출현 갈림길: 포탈(위)에서 순환로 오른쪽 위 모서리까지 곧게 내려온다.
  static const double portalY = 58;
  static const double joinY = 211.2;

  static final double run = (yB - yT) / 2 * math.tan(math.pi / 6);
  static final double xL = xPL + run;
  static final double xR = xPR - run;
  static final double joinX = xR + (joinY - yT) / (cy - yT) * (xPR - xR);

  /// 길쭉한 육각형 꼭짓점 (오른쪽 위부터 시계 방향). [a] > 0 이면 바깥으로 a만큼 평행이동.
  static List<Offset> vertices([double a = 0]) {
    final t = a * math.tan(math.pi / 6);
    final s = a / math.sin(math.pi / 3);
    return [
      Offset(xR + t, yT - a),
      Offset(xPR + s, cy),
      Offset(xR + t, yB + a),
      Offset(xL - t, yB + a),
      Offset(xPL - s, cy),
      Offset(xL - t, yT - a),
    ];
  }

  /// 모서리를 둥글린 순환로. 시작점은 오른쪽 위 모서리 직전, 진행 방향은 시계 방향.
  static Path roundedLoop(List<Offset> v, double r) {
    Offset toward(Offset from, Offset to, double d) {
      final dir = to - from;
      return from + dir / dir.distance * d;
    }

    final n = v.length;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final c = v[i];
      final a = toward(c, v[(i - 1 + n) % n], r);
      final b = toward(c, v[(i + 1) % n], r);
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
    }
    path.close();
    return path;
  }

  static final Path loop = roundedLoop(vertices(), cornerRadius);
  static Path get spur => Path()
    ..moveTo(joinX, portalY)
    ..lineTo(joinX, joinY);

  static const List<Branch> branches = [
    Branch('창병', Color(0xFF9A3B2E), cx - 372),
    Branch('궁병', Color(0xFF3F6B3A), cx - 267),
    Branch('포수', Color(0xFF5E4E8C), cx - 162),
    Branch('기병', Color(0xFF8A6418), cx + 162),
    Branch('수군', Color(0xFF2E5E8C), cx + 267),
    Branch('술사', Color(0xFF4A4E54), cx + 372),
  ];

  /// 단계별 몬스터 이동 속도 (px/s). 1–10R, 11–20R, ...
  static const List<double> stageSpeed = [30, 33, 36, 40, 44, 48];
  static double speedForRound(int round) =>
      stageSpeed[math.min((round - 1) ~/ 10, stageSpeed.length - 1)];
}

class Branch {
  final String name;
  final Color color;
  final double x;
  const Branch(this.name, this.color, this.x);
}

/// 몬스터 이동 경로: 갈림길을 내려온 뒤 순환로를 시계 방향으로 계속 돈다.
class RoadTrack {
  RoadTrack() {
    _loop = Board.loop.computeMetrics().first;
    loopLength = _loop.length;
    spurLength = Board.joinY - Board.portalY;
    final target = Offset(Board.joinX, Board.joinY);
    var best = 0.0;
    var bestDist = double.infinity;
    for (var d = 0.0; d < loopLength; d += 1) {
      final p = _loop.getTangentForOffset(d)!.position;
      final dist = (p - target).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = d;
      }
    }
    joinDistance = best;
    for (var d = 0.0; d < loopLength; d += 8) {
      _samples.add(_loop.getTangentForOffset(d)!.position);
    }
    for (var y = Board.portalY; y <= Board.joinY; y += 8) {
      _samples.add(Offset(Board.joinX, y));
    }
  }

  final List<Offset> _samples = [];

  /// 길 중심선까지의 거리 (배치 가능 판정용).
  double distanceToRoad(Offset p) {
    var best = double.infinity;
    for (final s in _samples) {
      final d = (s - p).distanceSquared;
      if (d < best) best = d;
    }
    return math.sqrt(best);
  }

  late final PathMetric _loop;
  late final double loopLength;
  late final double spurLength;
  late final double joinDistance;

  Tangent _at(double s) {
    if (s < spurLength) {
      return Tangent(Offset(Board.joinX, Board.portalY + s), const Offset(0, 1));
    }
    final d = (joinDistance + s - spurLength) % loopLength;
    return _loop.getTangentForOffset(d)!;
  }

  Offset positionAt(double s) => _at(s).position;
  Offset directionAt(double s) => _at(s).vector;
}
