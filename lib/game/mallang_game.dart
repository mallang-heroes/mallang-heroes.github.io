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

  /// 맵 유닛 그림: 병과 → [군졸, 정병, 군관, 장수] (그림이 없는 등급은 null).
  final Map<String, List<UnitArt?>> fieldArt = {};

  /// 막사 창 등급별 대기 시트 (군졸·정병·군관·장수). 그림이 없는 병과는 없음.
  final Map<String, List<Sheet>> tierIdle = {};

  /// 보급병 걷기 시트 (군졸·정병·군관).
  final Map<String, List<Sheet>> tierWalk = {};
  final List<SupplyWalker> walkers = [];
  final rng = math.Random();
  final List<Monster> monsters = [];

  /// 몬스터 그림 (폴더 이름 → 그림). 못 불러온 종은 임시 말랑이로 그린다.
  final Map<String, MonsterArt> monsterArt = {};
  final Map<String, Barracks> barracks = {};
  final List<FieldUnit> units = [];

  /// 병과별 보급 방향: true면 막사로, false면 맵에 소환 (궁에서 설정).
  final Map<String, bool> supplyToBarracks = {for (final b in Rules.branches) b: false};

  /// 상세 창이 열린 유닛 / 집기로 들고 있는 유닛.
  FieldUnit? detailUnit;
  FieldUnit? heldUnit;

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
    // 맵 유닛 그림 (군졸·정병·군관: 대기·걷기 / 장수: 대기·공격, 걷기는 있으면)
    for (final b in Board.branches) {
      if (!slimeBranches.contains(b.key)) continue;
      final arts = <UnitArt?>[];
      final idles = <Sheet>[];
      final walks = <Sheet>[];
      for (final t in const ['gunjol', 'jeongbyeong', 'gungwan']) {
        final dir = 'units/${b.key}/$t/unit-${b.key}-$t';
        final idle = await Sheet.load(images, '$dir-idle.json');
        final walk = await Sheet.load(images, '$dir-walk.json');
        idles.add(idle);
        walks.add(walk);
        arts.add(UnitArt(idle, null, walk));
      }
      final dir = 'units/${b.key}/jangsu/unit-${b.key}-jangsu';
      Sheet? walk;
      try {
        walk = await Sheet.load(images, '$dir-walk.json');
      } catch (_) {
        walk = null; // 장수 걷기 그림은 아직 없음
      }
      arts.add(UnitArt(
        await Sheet.load(images, '$dir-idle.json'),
        await Sheet.load(images, '$dir-attack.json'),
        walk,
      ));
      fieldArt[b.name] = arts;
      tierIdle[b.name] = [...idles, arts[3]!.idle];
      tierWalk[b.name] = walks;
    }
    // 몬스터 12종 (스테이지별 일반·보스)
    for (var st = 0; st < monsterKinds.length; st++) {
      for (final isBoss in const [false, true]) {
        final key = monsterKey(st, isBoss);
        try {
          monsterArt[key] = await MonsterArt.load(images, key);
        } catch (e) {
          debugPrint('몬스터 그림을 못 불러옴: $key ($e)');
        }
      }
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
    await world.add(PlaceCatcher());
    await world.add(Hud());
    _startRound();
  }

  void restart() {
    for (final m in monsters) {
      m.removeFromParent();
    }
    monsters.clear();
    for (final u in units) {
      u.removeFromParent();
    }
    units.clear();
    for (final w in walkers) {
      w.removeFromParent();
    }
    walkers.clear();
    for (final b in barracks.values) {
      b.counts.setAll(0, [0, 0, 0, 0]);
    }
    detailUnit = null;
    heldUnit = null;
    overlays.removeAll(['detail', 'held', 'palace', 'barracks']);
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
    // 궁 문 앞에서 나와, 막사로 가거나(막사로) 막사 앞 빈자리로 간다(소환).
    final door = Offset(map.palace.foot.dx, map.palace.foot.dy - 4);
    palace.bounce();
    var i = 0;
    for (final (br, tier) in got) {
      final b = barracks[br]!;
      if (supplyToBarracks[br]!) {
        final w = SupplyWalker(br, tier, door, b.door, i * 0.18);
        walkers.add(w);
        world.add(w);
      } else {
        _spawnUnit(br, tier, door, delay: i * 0.18);
      }
      i++;
    }
  }

  void supplyArrived(SupplyWalker w) {
    walkers.remove(w);
    _enterBarracks(w.branch, w.tier);
  }

  void _enterBarracks(String branch, int tier) {
    final b = barracks[branch]!;
    b.counts[tier]++;
    b.bounce();
    world.add(FloatText('+1 ${Rules.tierNames[tier]}', b.position + Vector2(0, -b.size.y - 14),
        const Color(0xFFFFF4D6)));
    _changed();
  }

  /// [from]에서 나타나 해당 막사 앞 빈자리로 걸어가는 유닛을 만든다.
  FieldUnit? _spawnUnit(String branch, int tier, Offset from, {double delay = 0}) {
    final b = barracks[branch]!;
    // 막사 아래쪽 길가(사거리가 길에 닿는 자리)부터 찾는다.
    final spot = _nearestFree(Offset(b.position.x, b.position.y + 160), spacing: tier >= 3 ? 33 : 24);
    if (spot == null) {
      toast('맵에 자리가 없어서 $branch ${Rules.tierNames[tier]}이(가) 막사로 들어갔어요');
      _enterBarracks(branch, tier);
      return null;
    }
    final u = FieldUnit(branch, tier, Vector2(from.dx, from.dy), delay: delay);
    units.add(u);
    world.add(u);
    u.moveTo(Vector2(spot.dx, spot.dy), run: false);
    return u;
  }

  /// 막사로 돌아온 유닛이 문에 닿았을 때.
  void unitEntered(FieldUnit u) {
    units.remove(u);
    u.removeFromParent();
    if (detailUnit == u) closeDetail();
    if (heldUnit == u) cancelHeld();
    _enterBarracks(u.branch, u.tier);
  }

  void killMonster(Monster m) {
    monsters.remove(m);
    m.removeFromParent();
    final fx = m.deathEffect();
    if (fx != null) world.add(fx);
    kills++;
    silver += Rules.silverPerKill[Rules.stage(m.round)];
  }

  void _end(Phase p, String reason) {
    phase = p;
    endReason = reason;
    overlays.removeAll(['barracks', 'detail', 'held', 'palace']);
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

  /// 배치 가능: 길 · 궁 · 막사 · 포탈 · 다른 유닛 위가 아니어야 한다.
  bool canPlace(Offset p, {FieldUnit? except, double? spacing}) {
    final me = spacing ?? except?.spacing ?? 33;
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
    for (final u in units) {
      if (u == except || u.returning) continue;
      if ((u.restSpot.toOffset() - p).distance < me + u.spacing) return false;
    }
    return true;
  }

  Offset? _nearestFree(Offset from, {double spacing = 33}) {
    for (var r = 0.0; r < 420; r += 12) {
      for (var a = 0; a < 360; a += 15) {
        final x = ((from.dx + r * math.cos(a * math.pi / 180)) / 12).roundToDouble() * 12;
        final y = ((from.dy + r * math.sin(a * math.pi / 180)) / 12).roundToDouble() * 12;
        if (canPlace(Offset(x, y), spacing: spacing)) return Offset(x, y);
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
    if (detailUnit != null) closeDetail();
    overlays.remove('palace');
    selectedBranch = branch;
    overlays.add('barracks');
    _changed();
  }

  void closeBarracks() {
    overlays.remove('barracks');
    selectedBranch = null;
  }

  /// 막사 + 맵에 있는 해당 병과·등급 수.
  int countOf(String branch, int tier) =>
      barracks[branch]!.counts[tier] +
      units.where((u) => u.branch == branch && u.tier == tier && !u.returning).length;

  int fieldCount(String branch, int tier) =>
      units.where((u) => u.branch == branch && u.tier == tier && !u.returning).length;

  bool canSummonGeneral(String branch) => [0, 1, 2].every((t) => countOf(branch, t) > 0);

  /// 재료 1명 쓰기: 막사에 있으면 막사에서, 없으면 맵에서.
  void _take(String branch, int tier) {
    final b = barracks[branch]!;
    if (b.counts[tier] > 0) {
      b.counts[tier]--;
      return;
    }
    final u = units.firstWhere((u) => u.branch == branch && u.tier == tier && !u.returning);
    units.remove(u);
    u.removeFromParent();
    if (detailUnit == u) closeDetail();
    if (heldUnit == u) cancelHeld();
  }

  /// 새로 생긴 유닛: 그 병과 보급 설정이 '막사로'면 막사로, 아니면 막사 문에서 나와 맵으로.
  void _deliver(String branch, int tier) {
    if (supplyToBarracks[branch]!) {
      _enterBarracks(branch, tier);
    } else {
      final b = barracks[branch]!;
      b.bounce();
      _spawnUnit(branch, tier, b.door);
    }
  }

  /// 같은 병과 3명 → 무작위 병과의 다음 등급 1명 (막사·맵 재료 모두 사용).
  void promote(String branch, int tier) {
    if (tier > 1 || countOf(branch, tier) < 3) return;
    for (var k = 0; k < 3; k++) {
      _take(branch, tier);
    }
    final to = Rules.branches[rng.nextInt(Rules.branches.length)];
    _deliver(to, tier + 1);
    toast('$branch ${Rules.tierNames[tier]} 3명 → $to ${Rules.tierNames[tier + 1]}');
    _changed();
  }

  /// 같은 병과 군관 + 정병 + 군졸 → 장수 (막사 문에서 나와 막사 앞에 선다).
  void summonGeneral(String branch) {
    if (!canSummonGeneral(branch)) return;
    for (var t = 0; t < 3; t++) {
      _take(branch, t);
    }
    final b = barracks[branch]!;
    b.bounce();
    _spawnUnit(branch, 3, b.door);
    toast('$branch 장수 소환! 끌어서 놓으면 그 자리로 걸어가요');
    _changed();
  }

  /// 막사에서 1명 꺼내 맵으로.
  void takeOut(String branch, int tier) {
    final b = barracks[branch]!;
    if (b.counts[tier] <= 0) return;
    b.counts[tier]--;
    b.bounce();
    _spawnUnit(branch, tier, b.door);
    _changed();
  }

  void sell(String branch, int tier) {
    final b = barracks[branch]!;
    if (tier > 2 || b.counts[tier] <= 0) return;
    b.counts[tier]--;
    silver += Rules.sellPrice[tier];
    toast('$branch ${Rules.tierNames[tier]} 판매 +${Rules.sellPrice[tier]}냥');
    _changed();
  }

  // ── 유닛 상세 · 집기 · 궁 설정 ──

  void openDetail(FieldUnit u) {
    if (phase != Phase.playing) return;
    if (heldUnit != null) {
      placeUnit(heldUnit!, u.position.toOffset());
      return;
    }
    detailUnit?.selected = false;
    detailUnit = u;
    u.selected = true;
    overlays.remove('barracks');
    overlays.remove('palace');
    overlays.add('detail');
    _changed();
  }

  void closeDetail() {
    detailUnit?.selected = false;
    detailUnit = null;
    overlays.remove('detail');
    _changed();
  }

  /// 상세 창 '집기': 놓을 곳을 누르면 그 자리로 이동.
  void pickUp() {
    final u = detailUnit;
    if (u == null) return;
    closeDetail();
    heldUnit = u;
    overlays.add('held');
    _changed();
  }

  void cancelHeld() {
    heldUnit = null;
    overlays.remove('held');
    _changed();
  }

  /// 상세 창 '막사로 보내기'.
  void sendHome() {
    final u = detailUnit;
    if (u == null) return;
    closeDetail();
    u.sendHome();
    _changed();
  }

  /// 유닛을 [p]로 옮긴다 (끌어 놓기 · 집기 공용). 못 놓는 곳이면 알림만.
  void placeUnit(FieldUnit u, Offset p) {
    final snapped = Offset((p.dx / 12).roundToDouble() * 12, (p.dy / 12).roundToDouble() * 12);
    if (!canPlace(snapped, except: u)) {
      toast('길 · 궁 · 막사 · 다른 유닛 위에는 놓을 수 없어요');
      return;
    }
    if (heldUnit == u) cancelHeld();
    if ((Vector2(snapped.dx, snapped.dy) - u.position).length < 2) return;
    u.moveTo(Vector2(snapped.dx, snapped.dy));
  }

  /// 빈 땅을 눌렀을 때 (집기 중이면 그 자리로 옮김).
  void tapGround(Offset p) {
    final u = heldUnit;
    if (u != null) placeUnit(u, p);
  }

  void openPalace() {
    if (phase != Phase.playing) return;
    if (detailUnit != null) closeDetail();
    overlays.remove('barracks');
    overlays.add('palace');
    _changed();
  }

  void closePalace() {
    overlays.remove('palace');
    _changed();
  }

  void setSupply(String branch, bool toBarracks) {
    supplyToBarracks[branch] = toBarracks;
    _changed();
  }

  void setAllSupply(bool toBarracks) {
    for (final b in Rules.branches) {
      supplyToBarracks[b] = toBarracks;
    }
    _changed();
  }

  // ── 강화 ──
  double atkMul(int group) => 1 + Rules.atkPerLv * upgradeLv[group];
  double speedMul(int group) => 1 + Rules.speedPerLv * upgradeLv[group];
  int upgradeCost(int group) => Rules.upgradeBase[group] + Rules.upgradeStep[group] * upgradeLv[group];

  /// 성공 50%, 실패해도 비용은 사라진다.
  void tryUpgrade(int group) {
    if (phase != Phase.playing) return;
    if (upgradeLv[group] >= Rules.upgradeMax[group]) {
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
