import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'board.dart';
import 'hud.dart';
import 'map_layer.dart';
import 'monster.dart';
import 'rules.dart';
import 'sheets.dart';
import 'units.dart';

enum Phase { playing, won, lost }

/// 아래 트레이의 탭.
enum TrayTab { barracks, upgrade, relic, effect }

class MallangGame extends FlameGame {
  MallangGame._(World w)
      : super(
          world: w,
          camera: CameraComponent.withFixedResolution(
              width: Board.width, height: Board.height, world: w),
        );
  factory MallangGame() => MallangGame._(World());

  late final RoadTrack track;
  late final Palace palace;

  /// 맵 유닛 그림: 병과 → [군졸, 정병, 군관, 장수] (그림이 없는 등급은 null).
  final Map<String, List<UnitArt?>> fieldArt = {};

  /// 막사 카드·막사 안 등급별 대기 시트 (군졸·정병·군관·장수). 아직 못 받았으면 null.
  final Map<String, List<Sheet?>> tierIdle = {};

  final rng = math.Random();
  final List<Monster> monsters = [];

  /// 몬스터 그림 (폴더 이름 → 그림). 못 불러온 종은 임시 말랑이로 그린다.
  final Map<String, MonsterArt> monsterArt = {};
  final Map<String, Barracks> barracks = {
    for (final b in Rules.branches) b: Barracks(b),
  };
  final List<FieldUnit> units = [];

  /// 상세 창이 열린 유닛 / 집기로 들고 있는 유닛.
  FieldUnit? detailUnit;
  FieldUnit? heldUnit;

  /// 화면(Flutter UI)이 다시 그려져야 할 때 올린다.
  final changes = ValueNotifier<int>(0);
  void _changed() => changes.value++;

  /// 트레이: 지금 탭, 막사 안을 보고 있는 병과(없으면 막사 목록).
  TrayTab tab = TrayTab.barracks;
  String? openBranch;

  /// 막사에 새 유닛이 들어왔는데 다른 탭을 보고 있으면 막사 탭에 빨간 점.
  bool barracksDot = false;

  int round = 0;
  double roundTime = 0;
  int _spawnLeft = 0;
  int _spawnIndex = 0;
  double _spawnTimer = 0;
  Monster? boss;
  Phase phase = Phase.playing;
  String endReason = '';
  int kills = 0;
  int silver = 0;
  int palaceHp = Rules.palaceHp;
  final List<int> upgradeLv = [0, 0, 0, 0, 0];
  double gameSpeed = 1;
  String? toastText;
  double _toastTime = 0;

  /// 은냥 칸이 톡 커지는 연출 (엽전이 도착할 때 올라감).
  final coinBump = ValueNotifier<int>(0);

  /// 무료 뽑기권 (시작 1장 + 라운드마다 1장, 최대 [Rules.maxFreeDraws]장).
  int freeDraws = 0;

  /// 1라운드 전 준비 시간 (남은 초). 0이면 준비 끝.
  double prepLeft = 0;
  bool get preparing => prepLeft > 0;

  @override
  Color backgroundColor() => const Color(0xFF7E9A52);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    track = RoadTrack();
    _assets = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet();
    for (final b in Board.branches) {
      fieldArt[b.name] = List<UnitArt?>.filled(4, null);
      tierIdle[b.name] = List<Sheet?>.filled(4, null);
    }
    // 1) 첫 화면에 꼭 필요한 것만 한꺼번에(동시에) 받는다: 맵·궁·동굴, 군졸 그림, 1스테이지 몬스터.
    palace = Palace();
    await Future.wait([
      _addTracked(MapLayer()),
      _addTracked(SpawnCave()),
      _addTracked(palace),
      for (final b in Board.branches)
        if (slimeBranches.contains(b.key)) _track(_loadTier(b, 0)),
      _track(_loadMonster(monsterKey(0, false))),
      _track(_loadMonster(monsterKey(0, true))),
    ]);
    await world.add(PlaceCatcher());
    loadProgress.value = 1;
    _startPrep();
    // 2) 나머지는 게임하면서 뒤에서 받는다 (다 받기 전에는 임시 그림으로 보임).
    _loadRest();
  }

  /// 시작 화면 진행률 (0~1).
  final loadProgress = ValueNotifier<double>(0);
  int _loadTotal = 0;
  int _loadDone = 0;
  Set<String> _assets = {};

  Future<T> _track<T>(Future<T> f) {
    _loadTotal++;
    return f.whenComplete(() {
      _loadDone++;
      loadProgress.value = math.min(0.99, _loadDone / _loadTotal);
    });
  }

  Future<void> _addTracked(Component c) => _track(Future.sync(() => world.add(c)));

  bool _has(String imagesPath) => _assets.contains('assets/images/$imagesPath');

  /// 병과 [b]의 [tier] 등급 그림 (군졸~군관: 대기·걷기 / 장수: 대기·공격, 걷기는 파일이 있을 때만).
  Future<void> _loadTier(Branch b, int tier) async {
    const names = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu'];
    final dir = 'units/${b.key}/${names[tier]}/unit-${b.key}-${names[tier]}';
    if (tier < 3) {
      final r = await Future.wait([
        Sheet.load(images, '$dir-idle.json'),
        Sheet.load(images, '$dir-walk.json'),
      ]);
      fieldArt[b.name]![tier] = UnitArt(r[0], null, r[1]);
      tierIdle[b.name]![tier] = r[0];
    } else {
      final hasWalk = _has('$dir-walk.json');
      final r = await Future.wait([
        Sheet.load(images, '$dir-idle.json'),
        Sheet.load(images, '$dir-attack.json'),
        if (hasWalk) Sheet.load(images, '$dir-walk.json'),
      ]);
      fieldArt[b.name]![3] = UnitArt(r[0], r[1], hasWalk ? r[2] : null);
      tierIdle[b.name]![3] = r[0];
    }
  }

  Future<void> _loadMonster(String key) async {
    try {
      monsterArt[key] = await MonsterArt.load(images, key, has: _has);
    } catch (e) {
      debugPrint('몬스터 그림을 못 불러옴: $key ($e)');
    }
  }

  Future<void> _loadRest() async {
    try {
      await Future.wait([
        for (final b in Board.branches)
          if (slimeBranches.contains(b.key))
            for (var t = 1; t < 4; t++) _loadTier(b, t),
      ]);
      _changed();
      for (var st = 1; st < monsterKinds.length; st++) {
        await Future.wait([_loadMonster(monsterKey(st, false)), _loadMonster(monsterKey(st, true))]);
      }
    } catch (e) {
      debugPrint('뒤에서 그림 받기 실패: $e');
    }
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
    for (final b in barracks.values) {
      b.counts.setAll(0, [0, 0, 0]);
      b.flash = 0;
    }
    detailUnit = null;
    heldUnit = null;
    openBranch = null;
    tab = TrayTab.barracks;
    barracksDot = false;
    _spawnIndex = 0;
    _spawnLeft = 0;
    overlays.removeAll(['detail', 'held']);
    kills = 0;
    upgradeLv.setAll(0, [0, 0, 0, 0, 0]);
    boss = null;
    phase = Phase.playing;
    overlays.remove('result');
    _startPrep();
  }

  @override
  void update(double dt) {
    if (phase != Phase.playing) return;
    super.update(dt * gameSpeed);
    _tick(dt * gameSpeed);
  }

  /// 트레이 숫자·타이머가 부드럽게 갱신되도록 화면을 다시 그리는 간격.
  double _uiTick = 0;

  void _tick(double dt) {
    _refreshCounts();
    final real = dt / gameSpeed;
    if (_toastTime > 0) {
      _toastTime -= real;
      if (_toastTime <= 0) {
        toastText = null;
        _changed();
      }
    }
    for (final b in barracks.values) {
      if (b.flash > 0) {
        b.flash = math.max(0, b.flash - real);
        if (b.flash == 0) _changed();
      }
    }
    _uiTick += real;
    if (_uiTick >= 0.1) {
      _uiTick = 0;
      _changed();
    }
    if (prepLeft > 0) {
      prepLeft -= dt;
      if (prepLeft <= 0) {
        prepLeft = 0;
        _startRound();
      }
      return;
    }
    roundTime += dt;

    if (_spawnLeft > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawn(false, lane: _spawnIndex.isEven ? -Rules.laneOffset : Rules.laneOffset);
        _spawnIndex++;
        _spawnLeft--;
        _spawnTimer = Rules.spawnGap;
      }
    }

    if (roundTime >= Rules.roundSeconds && round < Rules.lastRound) {
      _roundBonus();
      _startRound();
    }
  }

  /// 준비 라운드: 시작 은냥과 무료 뽑기권을 주고 [Rules.prepSeconds]초 뒤 1라운드.
  void _startPrep() {
    round = 0;
    roundTime = 0;
    prepLeft = Rules.prepSeconds;
    silver = Rules.startSilver;
    freeDraws = Rules.startFreeDraws;
    palaceHp = Rules.palaceHp;
    _changed();
  }

  /// 라운드를 넘길 때 보너스 은냥 (궁에서 엽전이 날아간다).
  void _roundBonus() {
    final gain = Rules.roundClearBonus;
    silver += gain;
    world.add(CoinFly(MapData.palace.translate(0, -60), gain));
    toast('$round라운드 통과 보너스 +$gain냥');
  }

  void _startRound() {
    round++;
    roundTime = 0;
    _spawnLeft = Rules.mobsPerRound;
    _spawnTimer = 0;
    if (round % 10 == 0) boss = _spawn(true);
    freeDraws = math.min(Rules.maxFreeDraws, freeDraws + Rules.freeDrawsPerRound);
    _changed();
  }

  Monster _spawn(bool isBoss, {double lane = 0}) {
    final m = Monster(round: round, speed: Board.speedForRound(round), boss: isBoss, lane: lane);
    monsters.add(m);
    world.add(m);
    return m;
  }

  /// 마지막 라운드 몬스터를 모두 처리하면 승리.
  void _checkWin() {
    if (phase == Phase.playing && round >= Rules.lastRound && _spawnLeft == 0 && monsters.isEmpty) {
      _end(Phase.won, '60라운드를 모두 막아냈어요!');
    }
  }

  /// 몬스터가 궁에 닿음: 일반은 궁 체력 −1, 보스는 바로 패배.
  void monsterReachedPalace(Monster m) {
    if (phase != Phase.playing) return;
    monsters.remove(m);
    m.dead = true;
    m.removeFromParent();
    palace.bounce();
    if (m.boss) {
      if (boss == m) boss = null;
      _end(Phase.lost, '$round라운드 보스가 궁에 들어왔어요');
      return;
    }
    palaceHp = math.max(0, palaceHp - 1);
    world.add(FloatText('−1', Vector2(MapData.palace.dx, MapData.palace.dy - 130), const Color(0xFFFF8A7A)));
    if (palaceHp <= 0) {
      _end(Phase.lost, '궁 체력이 모두 닳았어요');
      return;
    }
    _checkWin();
    _changed();
  }

  bool get canDraw => phase == Phase.playing && (freeDraws > 0 || silver >= Rules.drawCost);

  /// 뽑기: 무료권이 있으면 먼저 쓰고, 없으면 [Rules.drawCost]냥. 무작위 병과 군졸 1명이 그 병과 막사로 들어간다.
  bool draw() {
    if (!canDraw) {
      if (phase == Phase.playing) toast('은냥이 모자라요 (뽑기 ${Rules.drawCost}냥)');
      return false;
    }
    if (freeDraws > 0) {
      freeDraws--;
    } else {
      silver -= Rules.drawCost;
    }
    final br = Rules.branches[rng.nextInt(Rules.branches.length)];
    _enterBarracks(br, 0);
    toast('$br 군졸 +1 → $br 막사');
    return true;
  }

  void _enterBarracks(String branch, int tier) {
    final b = barracks[branch]!;
    b.counts[tier]++;
    b.bounce();
    if (tab != TrayTab.barracks) barracksDot = true;
    _changed();
  }

  /// 칸 [tile]의 주인 (이동 중이면 목적지 기준). 없으면 null.
  FieldUnit? occupantOf(int tile, {FieldUnit? except}) {
    final foot = MapData.footOf(tile);
    for (final u in units) {
      if (u == except || u.returning) continue;
      if ((u.restSpot.toOffset() - foot).distance < 2) return u;
    }
    return null;
  }

  /// [p]가 들어 있는 칸 번호 (칸 바깥이면 null).
  int? tileAt(Offset p) {
    for (var i = 0; i < MapData.tiles.length; i++) {
      final r = Rect.fromCenter(center: MapData.tiles[i], width: MapData.pitch, height: MapData.pitch);
      if (r.contains(p)) return i;
    }
    return null;
  }

  /// 끄는 중 그림자를 붙일 칸의 발 위치 (칸 바깥이면 null).
  Offset? tileFootNear(Offset foot) {
    final i = tileAt(foot.translate(0, -14));
    return i == null ? null : MapData.footOf(i);
  }

  /// [from]에서 가장 가까운 빈 칸 (없으면 null).
  int? _nearestFreeTile(Offset from) {
    int? best;
    var bestD = double.infinity;
    for (var i = 0; i < MapData.tiles.length; i++) {
      if (occupantOf(i) != null) continue;
      final d = (MapData.tiles[i] - from).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// [from]에서 나타나 가장 가까운 빈 칸으로 걸어가는 유닛을 만든다.
  FieldUnit? _spawnUnit(String branch, int tier, Offset from) {
    final tile = _nearestFreeTile(from);
    if (tile == null) {
      if (tier >= 3) {
        toast('빈 칸이 없어요');
        return null;
      }
      toast('빈 칸이 없어서 $branch ${Rules.tierNames[tier]}이(가) 막사로 들어갔어요');
      _enterBarracks(branch, tier);
      return null;
    }
    final u = FieldUnit(branch, tier, Vector2(from.dx, from.dy));
    units.add(u);
    world.add(u);
    final foot = MapData.footOf(tile);
    u.moveTo(Vector2(foot.dx, foot.dy), run: false);
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
    if (boss == m) boss = null;
    final fx = m.deathEffect();
    if (fx != null) world.add(fx);
    kills++;
    final gain = Rules.silverPerKill[Rules.stage(m.round)];
    silver += gain;
    world.add(CoinFly(m.position.toOffset().translate(0, -m.size.y * 0.5), gain));
    _checkWin();
  }

  /// 엽전이 은냥 칸에 도착.
  void coinArrived(int amount) => coinBump.value++;

  void _end(Phase p, String reason) {
    phase = p;
    endReason = reason;
    overlays.removeAll(['detail', 'held']);
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

  /// 배치 가능: 칸 위여야 한다 (다른 유닛이 있는 칸이면 자리를 바꾼다).
  bool canPlace(Offset foot, {FieldUnit? except}) => tileAt(foot.translate(0, -14)) != null;

  void toast(String text) {
    toastText = text;
    _toastTime = 2.2;
    _changed();
  }

  // ── 트레이 ──

  void selectTab(TrayTab t) {
    tab = t;
    openBranch = null;
    if (t == TrayTab.barracks) barracksDot = false;
    _changed();
  }

  void openBarracks(String branch) {
    if (phase != Phase.playing) return;
    tab = TrayTab.barracks;
    openBranch = branch;
    barracksDot = false;
    _changed();
  }

  void closeBarracks() {
    openBranch = null;
    _changed();
  }

  /// 막사 + 맵에 있는 해당 병과·등급 수 (장수는 맵에만 있음).
  int countOf(String branch, int tier) =>
      (tier < 3 ? barracks[branch]!.counts[tier] : 0) +
      units.where((u) => u.branch == branch && u.tier == tier && !u.returning).length;

  int fieldCount(String branch, int tier) =>
      units.where((u) => u.branch == branch && u.tier == tier && !u.returning).length;

  bool canSummonGeneral(String branch) => [0, 1, 2].every((t) => countOf(branch, t) > 0);

  /// 재료 1명 쓰기: 막사에 있으면 막사에서, 없으면 맵에서.
  void _take(String branch, int tier) {
    final b = barracks[branch]!;
    if (tier < 3 && b.counts[tier] > 0) {
      b.counts[tier]--;
      return;
    }
    final u = units.firstWhere((u) => u.branch == branch && u.tier == tier && !u.returning);
    _removeUnit(u);
  }

  /// 승진으로 새로 생긴 유닛은 그 병과 막사로 들어간다 (장수는 맵의 빈 칸으로).
  void _deliver(String branch, int tier) {
    if (tier < 3) {
      _enterBarracks(branch, tier);
    } else {
      _spawnUnit(branch, tier, barracks[branch]!.door);
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

  /// 같은 병과 군관 + 정병 + 군졸 → 장수 (맵 아래에서 나와 빈 칸으로 간다).
  void summonGeneral(String branch) {
    if (!canSummonGeneral(branch)) return;
    for (var t = 0; t < 3; t++) {
      _take(branch, t);
    }
    barracks[branch]!.bounce();
    _spawnUnit(branch, 3, barracks[branch]!.door);
    toast('$branch 장수 소환!');
    _changed();
  }

  /// 상세 창의 승진 버튼: 누른 유닛을 재료로 먼저 쓰고, 모자라는 재료는 막사 → 맵 순서로.
  void promoteFrom(FieldUnit u) {
    if (u.tier >= 3 || u.returning) return;
    final br = u.branch;
    if (u.tier < 2) {
      if (countOf(br, u.tier) < 3) return;
      _removeUnit(u);
      for (var k = 0; k < 2; k++) {
        _take(br, u.tier);
      }
      final to = Rules.branches[rng.nextInt(Rules.branches.length)];
      _deliver(to, u.tier + 1);
      toast('$br ${Rules.tierNames[u.tier]} 3명 → $to ${Rules.tierNames[u.tier + 1]}');
    } else {
      if (!canSummonGeneral(br)) return;
      _removeUnit(u);
      _take(br, 0);
      _take(br, 1);
      _spawnUnit(br, 3, barracks[br]!.door);
      toast('$br 장수 소환!');
    }
    _changed();
  }

  void _removeUnit(FieldUnit u) {
    units.remove(u);
    u.removeFromParent();
    if (detailUnit == u) closeDetail();
    if (heldUnit == u) cancelHeld();
  }

  /// 맵 유닛 머리 위 승진 표시: 같은 병과·등급 수 (프레임마다 한 번 계산).
  final Map<(String, int), int> _countCache = {};
  int cachedCount(String branch, int tier) => _countCache[(branch, tier)] ?? 0;
  void _refreshCounts() {
    _countCache.clear();
    for (final b in Rules.branches) {
      for (var t = 0; t < 3; t++) {
        _countCache[(b, t)] = countOf(b, t);
      }
    }
  }

  /// 막사에서 1명 꺼내 맵의 빈 칸으로 (배치).
  void takeOut(String branch, int tier) {
    final b = barracks[branch]!;
    if (tier > 2 || b.counts[tier] <= 0) return;
    if (_nearestFreeTile(b.door) == null) {
      toast('빈 칸이 없어요');
      return;
    }
    b.counts[tier]--;
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

  // ── 유닛 상세 · 집기 ──

  void openDetail(FieldUnit u) {
    if (phase != Phase.playing) return;
    if (heldUnit != null) {
      placeUnit(heldUnit!, u.position.toOffset());
      return;
    }
    detailUnit?.selected = false;
    detailUnit = u;
    u.selected = true;
    overlays.add('detail');
    _changed();
  }

  void closeDetail() {
    detailUnit?.selected = false;
    detailUnit = null;
    overlays.remove('detail');
    _changed();
  }

  /// 상세 창 '집기': 놓을 칸을 누르면 그 칸으로 이동.
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

  /// 상세 창 '막사로 보내기' (장수는 막사에 들어가지 않음).
  void sendHome() {
    final u = detailUnit;
    if (u == null || u.tier >= 3) return;
    closeDetail();
    u.sendHome();
    _changed();
  }

  /// 유닛을 발 위치 [foot]가 있는 칸으로 옮긴다 (끌어 놓기 · 집기 공용).
  /// 칸에 다른 유닛이 있으면 서로 자리를 바꾼다.
  void placeUnit(FieldUnit u, Offset foot) {
    final tile = tileAt(foot.translate(0, -14));
    if (tile == null) {
      toast('칸 위에만 놓을 수 있어요');
      return;
    }
    if (heldUnit == u) cancelHeld();
    final to = MapData.footOf(tile);
    final other = occupantOf(tile, except: u);
    if (other != null) other.moveTo(u.restSpot.clone());
    if ((Vector2(to.dx, to.dy) - u.position).length < 2) return;
    u.moveTo(Vector2(to.dx, to.dy));
  }

  /// 빈 땅을 눌렀을 때 (집기 중이면 누른 칸으로 옮긴다).
  void tapGround(Offset p) {
    final u = heldUnit;
    if (u != null) placeUnit(u, p.translate(0, 14));
  }

  // ── 강화 ──
  double atkMul(int group) => 1 + Rules.atkPerLv * upgradeLv[group];
  double speedMul(int group) => 1 + Rules.speedPerLv * upgradeLv[group];
  int upgradeCost(int group) => Rules.upgradeBase[group] + Rules.upgradeStep[group] * upgradeLv[group];

  /// 강화할 수 있는 상태인지 (은냥이 모자라거나 최대면 버튼 비활성).
  bool canUpgrade(int group) =>
      phase == Phase.playing &&
      group < 2 &&
      upgradeLv[group] < Rules.upgradeMax[group] &&
      silver >= upgradeCost(group);

  /// 강화 시도. 성공 true / 실패 false / 못 함 null. 실패해도 비용은 사라진다.
  bool? tryUpgrade(int group) {
    if (!canUpgrade(group)) return null;
    final cost = upgradeCost(group);
    silver -= cost;
    final ok = rng.nextDouble() < Rules.upgradeChance;
    if (ok) upgradeLv[group]++;
    toast(ok
        ? '${Rules.upgradeNames[group]} 강화 성공! Lv ${upgradeLv[group]}'
        : '${Rules.upgradeNames[group]} 강화 실패');
    _changed();
    return ok;
  }

  void toggleSpeed() {
    gameSpeed = gameSpeed == 1 ? 2 : 1;
    _changed();
  }
}
