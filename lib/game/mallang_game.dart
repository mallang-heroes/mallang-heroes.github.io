import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'board.dart';
import 'hud.dart';
import 'map_layer.dart';
import 'monster.dart';
import 'rules.dart';
import 'sheets.dart';
import 'units.dart';

enum Phase { playing, won, lost }

class MallangGame extends FlameGame {
  MallangGame._(World w)
      : super(
          world: w,
          camera: CameraComponent.withFixedResolution(
              width: Board.width, height: Board.height, world: w),
        );
  factory MallangGame() => MallangGame._(World());

  late final MapData map;
  late final RoadTrack track;
  late final Palace palace;

  /// 그림이 준비된 병과의 장수 그림.
  final Map<String, UnitArt> unitArt = {};
  final rng = math.Random();
  final List<Monster> monsters = [];
  final Map<String, Barracks> barracks = {};
  final List<General> generals = [];

  /// 화면(오버레이)이 다시 그려져야 할 때 올린다.
  final changes = ValueNotifier<int>(0);
  void _changed() => changes.value++;

  int round = 0;
  double roundTime = 0;
  int _spawnLeft = 0;
  double _spawnTimer = 0;
  Monster? boss;
  Phase phase = Phase.playing;
  String endReason = '';
  int kills = 0;
  double gameSpeed = 1;
  String? selectedBranch;
  String? toastText;
  double _toastTime = 0;

  @override
  Color backgroundColor() => const Color(0xFF3E4A2E);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    map = await MapData.load();
    track = RoadTrack(map);
    unitArt['창병'] = UnitArt(
      await Sheet.load(images, 'units/spear/jangsu/unit-spear-jangsu-idle.json'),
      await Sheet.load(images, 'units/spear/jangsu/unit-spear-jangsu-attack.json'),
    );
    await world.add(MapLayer());
    await world.add(SpawnCave());
    palace = Palace();
    await world.add(palace);
    for (final b in Board.branches) {
      final c = Barracks(b.name, map.buildings[b.key]!);
      barracks[b.name] = c;
      await world.add(c);
    }
    await world.add(Hud());
    _startRound();
  }

  void restart() {
    for (final m in monsters) {
      m.removeFromParent();
    }
    monsters.clear();
    for (final g in generals) {
      g.removeFromParent();
    }
    generals.clear();
    for (final b in barracks.values) {
      b.counts.setAll(0, [0, 0, 0]);
    }
    round = 0;
    kills = 0;
    boss = null;
    phase = Phase.playing;
    overlays.remove('result');
    _startRound();
    _changed();
  }

  @override
  void update(double dt) {
    if (phase != Phase.playing) return;
    super.update(dt * gameSpeed);
    _tick(dt * gameSpeed);
  }

  void _tick(double dt) {
    if (_toastTime > 0) {
      _toastTime -= dt / gameSpeed;
      if (_toastTime <= 0) toastText = null;
    }
    roundTime += dt;

    if (_spawnLeft > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawn(false);
        _spawnLeft--;
        _spawnTimer = Rules.spawnGap;
      }
    }

    if (monsters.length > Rules.loseCount) {
      _end(Phase.lost, '몬스터가 ${Rules.loseCount}마리를 넘었어요');
      return;
    }

    if (roundTime >= Rules.roundSeconds) {
      final b = boss;
      if (b != null && !b.dead) {
        _end(Phase.lost, '$round라운드 보스를 10초 안에 잡지 못했어요');
        return;
      }
      if (round >= Rules.lastRound) {
        _end(Phase.won, '60라운드를 모두 막아냈어요!');
        return;
      }
      _startRound();
    }
  }

  void _startRound() {
    round++;
    roundTime = 0;
    _spawnLeft = Rules.mobsPerRound;
    _spawnTimer = 0;
    boss = null;
    if (round % 10 == 0) boss = _spawn(true);
    _supply();
    _changed();
  }

  Monster _spawn(bool isBoss) {
    final m = Monster(round: round, speed: Board.speedForRound(round), boss: isBoss);
    monsters.add(m);
    world.add(m);
    return m;
  }

  void _supply() {
    final got = Rules.supply(round, rng);
    final perBranch = <String, int>{};
    for (final (br, tier) in got) {
      barracks[br]!.counts[tier]++;
      perBranch[br] = (perBranch[br] ?? 0) + 1;
    }
    perBranch.forEach((br, n) {
      final b = barracks[br]!;
      b.bounce();
      world.add(FloatText('+$n', b.position + Vector2(0, -b.size.y - 14), const Color(0xFFFFF4D6)));
    });
  }

  void killMonster(Monster m) {
    monsters.remove(m);
    m.removeFromParent();
    kills++;
  }

  void _end(Phase p, String reason) {
    phase = p;
    endReason = reason;
    overlays.remove('barracks');
    overlays.add('result');
    _changed();
  }

  /// 길을 가장 많이 간 몬스터부터 n마리.
  List<Monster> leadMonsters(int n) {
    final live = monsters.where((m) => !m.dead).toList()
      ..sort((a, b) => b.traveled.compareTo(a.traveled));
    return live.take(n).toList();
  }

  /// 사거리 안에서 가장 앞선 몬스터부터 n마리 (광역은 그 둘레 가까운 순).
  List<Monster> monstersInRange(Vector2 at, double radius, int n) {
    final inRange = monsters.where((m) => !m.dead && m.position.distanceTo(at) <= radius).toList()
      ..sort((a, b) => b.traveled.compareTo(a.traveled));
    if (inRange.isEmpty || n == 1) return inRange.take(n).toList();
    final first = inRange.first;
    inRange.sort((a, b) =>
        a.position.distanceTo(first.position).compareTo(b.position.distanceTo(first.position)));
    return inRange.take(n).toList();
  }

  /// 배치 가능: 길 · 궁 · 막사 · 포탈 · 다른 장수 위가 아니어야 한다.
  bool canPlace(Offset p, {General? except}) {
    if (p.dx < 44 || p.dx > Board.playWidth - 44 || p.dy < 48 || p.dy > Board.height - 40) return false;
    if (track.distanceToRoad(p) < map.roadWidth / 2 + 28) return false;
    // 건물: 그림 둘레 + 아래 이름표 자리
    for (final b in map.buildings.values) {
      final r = Rect.fromLTRB(b.rect.left - 22, b.rect.top - 6, b.rect.right + 22, b.foot.dy + 34);
      if (r.contains(p)) return false;
    }
    for (final d in map.decorations) {
      if (d.blocks && (d.foot - p).distance < 36) return false;
    }
    if ((p.dx - map.cave.dx).abs() < 80 && p.dy < map.cave.dy + 40) return false;
    for (final g in generals) {
      if (g != except && (g.position.toOffset() - p).distance < 66) return false;
    }
    return true;
  }

  Offset? _nearestFree(Offset from) {
    for (var r = 0.0; r < 420; r += 12) {
      for (var a = 0; a < 360; a += 15) {
        final x = ((from.dx + r * math.cos(a * math.pi / 180)) / 12).roundToDouble() * 12;
        final y = ((from.dy + r * math.sin(a * math.pi / 180)) / 12).roundToDouble() * 12;
        if (canPlace(Offset(x, y))) return Offset(x, y);
      }
    }
    return null;
  }

  void toast(String text) {
    toastText = text;
    _toastTime = 2.2;
  }

  // ── 막사 창에서 부르는 동작 ──

  void openBarracks(String branch) {
    if (phase != Phase.playing) return;
    selectedBranch = branch;
    overlays.add('barracks');
    _changed();
  }

  void closeBarracks() {
    overlays.remove('barracks');
    selectedBranch = null;
  }

  /// 같은 병과 3명 → 무작위 병과의 다음 등급 1명.
  void promote(String branch, int tier) {
    final b = barracks[branch]!;
    if (tier > 1 || b.counts[tier] < 3) return;
    b.counts[tier] -= 3;
    final to = Rules.branches[rng.nextInt(Rules.branches.length)];
    barracks[to]!.counts[tier + 1]++;
    toast('$branch ${Rules.tierNames[tier]} 3명 → $to ${Rules.tierNames[tier + 1]}');
    _changed();
  }

  /// 같은 병과 군관 + 정병 + 군졸 → 장수 (빈 자리에 자동 배치).
  void summonGeneral(String branch) {
    final b = barracks[branch]!;
    if (!b.canSummonGeneral) return;
    final spot = _nearestFree(Offset(b.position.x, b.position.y - b.size.y - 70));
    if (spot == null) {
      toast('장수를 놓을 자리가 없어요');
      return;
    }
    for (var t = 0; t < 3; t++) {
      b.counts[t]--;
    }
    final g = General(branch, Vector2(spot.dx, spot.dy));
    generals.add(g);
    world.add(g);
    toast('$branch 장수 소환! 끌어서 옮길 수 있어요');
    _changed();
  }

  void sell(String branch, int tier) {
    final b = barracks[branch]!;
    if (b.counts[tier] <= 0) return;
    b.counts[tier]--;
    _changed();
  }

  void toggleSpeed() {
    gameSpeed = gameSpeed == 1 ? 2 : 1;
    _changed();
  }
}
