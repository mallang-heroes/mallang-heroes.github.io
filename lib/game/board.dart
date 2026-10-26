import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

/// 보드 좌표 (기준 해상도 1560×720, 오른쪽 156px은 패널).
class Board {
  static const double width = 1560;
  static const double height = 720;
  static const double playWidth = 1404;

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
  static const List<double> stageSpeed = [30, 33, 36, 40, 44, 48];
  static double speedForRound(int round) =>
      stageSpeed[math.min((round - 1) ~/ 10, stageSpeed.length - 1)];
}

class Branch {
  final String name;
  final String key; // 그림 파일 이름에 쓰는 영문 키
  final Color color;
  const Branch(this.name, this.key, this.color);
}

/// 건물 자리: 바닥 가운데(foot)와 보드 크기.
class BuildingSpot {
  final Offset foot;
  final double w;
  final double h;
  const BuildingSpot(this.foot, this.w, this.h);

  Rect get rect => Rect.fromLTWH(foot.dx - w / 2, foot.dy - h, w, h);
}

class Deco {
  final String kind;
  final Offset foot;
  final bool blocks;
  const Deco(this.kind, this.foot, this.blocks);
}

/// `assets/data/map-path.json` (제미나이 맵에서 추출한 경로·건물·장식 자리).
class MapData {
  MapData({
    required this.spawn,
    required this.loop,
    required this.roadWidth,
    required this.cave,
    required this.buildings,
    required this.decorations,
  });

  final List<Offset> spawn; // 동굴 입구 → 합류점
  final List<Offset> loop; // 합류점부터 시계 방향, 닫힌 고리
  final double roadWidth;
  final Offset cave;
  final Map<String, BuildingSpot> buildings; // palace, spear, archer, ...
  final List<Deco> decorations;

  BuildingSpot get palace => buildings['palace']!;

  static Future<MapData> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/data/map-path.json')) as Map<String, dynamic>;
    List<Offset> pts(List<dynamic> l) =>
        [for (final p in l) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())];
    Offset xy(Map<String, dynamic> m) => Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
    final b = j['buildings'] as Map<String, dynamic>;
    return MapData(
      spawn: pts(j['spawn']['points'] as List),
      loop: pts(j['loop']['points'] as List),
      roadWidth: (j['roadWidth'] as num).toDouble(),
      cave: xy(j['spawn']['cave_anchor'] as Map<String, dynamic>),
      buildings: {
        for (final e in b.entries)
          e.key: BuildingSpot(
            xy(e.value['foot'] as Map<String, dynamic>),
            (e.value['w'] as num).toDouble(),
            (e.value['h'] as num).toDouble(),
          ),
      },
      decorations: [
        for (final d in j['decorations'] as List)
          Deco(d['kind'] as String, Offset((d['x'] as num).toDouble(), (d['y'] as num).toDouble()),
              d['blocks'] as bool),
      ],
    );
  }
}

/// 꺾은선 하나를 길이로 따라가는 도구.
class _Polyline {
  _Polyline(this.pts, {required this.closed}) {
    final n = closed ? pts.length + 1 : pts.length;
    acc.add(0);
    for (var i = 1; i < n; i++) {
      acc.add(acc.last + (pts[i % pts.length] - pts[i - 1]).distance);
    }
  }

  final List<Offset> pts;
  final bool closed;
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
    final b = pts[(i + 1) % pts.length];
    final segLen = acc[i + 1] - acc[i];
    final t = segLen == 0 ? 0.0 : (s - acc[i]) / segLen;
    return Offset.lerp(a, b, t)!;
  }

  Offset dir(double s) {
    s = s.clamp(0, length);
    final i = _seg(s);
    final d = pts[(i + 1) % pts.length] - pts[i];
    return d.distance == 0 ? const Offset(1, 0) : d / d.distance;
  }
}

/// 몬스터 이동 경로: 동굴에서 갈림길을 내려온 뒤 순환로를 시계 방향으로 계속 돈다.
class RoadTrack {
  RoadTrack(this.map)
      : _spawn = _Polyline(map.spawn, closed: false),
        _loop = _Polyline(map.loop, closed: true) {
    for (var i = 0; i < map.loop.length; i += 2) {
      _samples.add(map.loop[i]);
    }
    for (var i = 0; i < map.spawn.length; i += 2) {
      _samples.add(map.spawn[i]);
    }
  }

  final MapData map;
  final _Polyline _spawn;
  final _Polyline _loop;
  final List<Offset> _samples = [];

  double get spawnLength => _spawn.length;
  double get loopLength => _loop.length;

  Offset positionAt(double s) =>
      s < _spawn.length ? _spawn.at(s) : _loop.at((s - _spawn.length) % _loop.length);

  Offset directionAt(double s) =>
      s < _spawn.length ? _spawn.dir(s) : _loop.dir((s - _spawn.length) % _loop.length);

  /// 길 중심선까지의 거리 (배치 가능 판정용).
  double distanceToRoad(Offset p) {
    var best = double.infinity;
    for (final s in _samples) {
      final d = (s - p).distanceSquared;
      if (d < best) best = d;
    }
    return math.sqrt(best);
  }
}
