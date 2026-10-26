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

  /// 막사 등급별 대기 시트 (군졸·정병·군관). 그림이 없는 병과는 없음.
  final Map<String, List<Sheet>> tierIdle = {};

  /// 보급병 걷기 시트 (군졸·정병·군관).
  final Map<String, List<Sheet>> tierWalk = {};
  final List<SupplyWalker> walkers = [];
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
  int silver = 0;
  final List<int> upgradeLv = [0, 0, 0, 0, 0];
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
    // 슬라임 장수 그림이 있는 병과 (나머지는 코드로 그린 임시 슬라임)
    for (final b in Board.branches) {
      if (!slimeBranches.contains(b.key)) continue;
      final dir = 'units/${b.key}/jangsu/unit-${b.key}-jangsu';
      Sheet? walk;
      try {
        walk = await Sheet.load(images, '$dir-walk.json');
      } catch (_) {
        walk = null; // 장수 걷기 그림은 아직 없음
      }
      unitArt[b.name] = UnitArt(
        await Sheet.load(images, '$dir-idle.json'),
        await Sheet.load(images, '$dir-attack.json'),
        walk,
      );
    }
    // 막사 창에 보이는 군졸·정병·군관 대기 동작
    for (final b in Board.branches) {
      if (!slimeBranches.contains(b.key)) continue;
      tierIdle[b.name] = [
        for (final t in const ['gunjol', 'jeongbyeong', 'gungwan'])
          await Sheet.load(images, 'units/${b.key}/$t/unit-${b.key}-$t-idle.json'),
      ];
      tierWalk[b.name] = [
        for (final t in const ['gunjol', 'jeongbyeong', 'gungwan'])
          await Sheet.load(images, 'units/${b.key}/$t/unit-${b.key}-$t-walk.json'),
      ];
    }
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
    for (final w in walkers) {
      w.removeFromParent();
    }
    walkers.clear();
    generals.clear();
    for (final b in barracks.values) {
      b.counts.setAll(0, [0, 0, 0]);
    }
    round = 0;
    kills = 0;
    silver = 0;
    upgradeLv.setAll(0, [0, 0, 0, 0, 0]);
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
    // 궁 문 앞에서 나와 각자 막사로 걸어간다 (도착해야 인원에 더해짐).
    final door = Offset(map.palace.foot.dx, map.palace.foot.dy - 4);
    palace.bounce();
    var i = 0;
    for (final (br, tier) in got) {
      final b = barracks[br]!;
      final w = SupplyWalker(br, tier, door, Offset(b.position.x, b.position.y - 4), i * 0.18);
      walkers.add(w);
      world.add(w);
      i++;
    }
  }

  void supplyArrived(SupplyWalker w) {
    walkers.remove(w);
    final b = barracks[w.branch]!;
    b.counts[w.tier]++;
    b.bounce();
    world.add(FloatText('+1 ${Rules.tierNames[w.tier]}', b.position + Vector2(0, -b.size.y - 14),
        const Color(0xFFFFF4D6)));
    _changed();
  }

  void killMonster(Monster m) {
    monsters.remove(m);
    m.removeFromParent();
    kills++;
    silver += Rules.silverPerKill[Rules.stage(m.round)];
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

  /// 사거리 안에서 가장 앞선 몬스터부터 n마리 (단일 1마리, 광역 3마리).
  List<Monster> monstersInRange(Vector2 at, double radius, int n) {
    final inRange = monsters.where((m) => !m.dead && m.position.distanceTo(at) <= radius).toList()
      ..sort((a, b) => b.traveled.compareTo(a.traveled));
    return inRange.take(n).toList();
  }

  /// 배치 가능: 길 · 궁 · 막사 · 포탈 · 다른 장수 위가 아니어야 한다.
  bool canPlace(Offset p, {General? except}) {
    if (p.dx < 44 || p.dx > Board.playWidth - 44 || p.dy < 48 || p.dy > Board.height - 40) return false;
    if (track.distanceToRoad(p) < map.roadWidth / 2 + 28) return false;
    // 건물: 그림 둘레 + 아래 이름표 자리
    for (final b in map.buildings.values) {
      final r = Rect.fromLTRB(b.rect.left - 22, b.rect.top - 6, b.rect.right + 22, b.foot.dy + 50);
      if (r.contains(p)) return false;
    }
    for (final d in map.decorations) {
      if (d.blocks && (d.foot - p).distance < 36) return false;
    }
    if ((p.dx - map.cave.dx).abs() < 80 && p.dy < map.cave.dy + 40) return false;
    for (final g in generals) {
      if (g != except && (g.restSpot.toOffset() - p).distance < 66) return false;
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
    // 막사 바로 앞(아래)에 나타난다. 끌어서 놓으면 그 자리까지 걸어간다.
    final spot = _nearestFree(Offset(b.position.x, b.position.y + 84));
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
    toast('$branch 장수 소환! 끌어서 놓으면 그 자리로 걸어가요');
    _changed();
  }

  void sell(String branch, int tier) {
    final b = barracks[branch]!;
    if (b.counts[tier] <= 0) return;
    b.counts[tier]--;
    silver += Rules.sellPrice[tier];
    toast('$branch ${Rules.tierNames[tier]} 판매 +${Rules.sellPrice[tier]}냥');
    _changed();
  }

  // ── 강화 ──
  double atkMul(int group) => 1 + Rules.atkPerLv * upgradeLv[group];
  double speedMul(int group) => 1 + Rules.speedPerLv * upgradeLv[group];
  int upgradeCost(int group) => Rules.upgradeBase[group] + Rules.upgradeStep[group] * upgradeLv[group];

  /// 성공 50%, 실패해도 비용은 사라진다.
  void tryUpgrade(int group) {
    if (phase != Phase.playing) return;
    if (upgradeLv[group] >= Rules.upgradeMax) {
      toast('${Rules.upgradeNames[group]} 최대 강화예요');
      return;
    }
    final cost = upgradeCost(group);
    if (silver < cost) {
      toast('은냥이 부족해요 ($cost냥 필요)');
      return;
    }
    silver -= cost;
    if (rng.nextDouble() < Rules.upgradeChance) {
      upgradeLv[group]++;
      toast('강화 성공! ${Rules.upgradeNames[group]} Lv${upgradeLv[group]}');
    } else {
      toast('강화 실패 (−$cost냥)');
    }
    _changed();
  }

  void toggleSpeed() {
    gameSpeed = gameSpeed == 1 ? 2 : 1;
    _changed();
  }
}
