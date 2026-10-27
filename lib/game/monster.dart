import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/cache.dart';
import 'package:flutter/painting.dart';

import 'mallang_game.dart';
import 'rules.dart';
import 'sheets.dart';

/// 스테이지(10라운드 묶음)별 몬스터 이름. assets/images/monsters/<mob|boss>-<이름>/
const List<String> monsterKinds = ['boar', 'tiger', 'gumiho', 'dokkaebi', 'ghost', 'zombie'];

/// 몬스터 폴더 이름: 일반은 mob-<이름>, 보스는 boss-<이름> (마지막 보스만 좀비가 된 왕).
String monsterKey(int stage, bool boss) {
  if (!boss) return 'mob-${monsterKinds[stage]}';
  if (stage == monsterKinds.length - 1) return 'boss-zombie-king';
  return 'boss-${monsterKinds[stage]}';
}

/// 몬스터 한 종의 그림 (모두 오른쪽을 봄, 왼쪽은 좌우 반전).
class MonsterArt {
  MonsterArt(this.walk, this.hit, this.die, this.appear, this.aura);

  final Sheet walk; // 걷기(귀신은 떠다니기) 반복
  final Sheet hit; // 맞을 때 하얀 번쩍임 1프레임
  final Sheet die; // 쓰러짐 한 번
  final Sheet? appear; // 보스 등장 한 번
  final Sheet? aura; // 좀비가 된 왕 뒤에 깔리는 기운

  /// 걷기·맞기·죽기(+보스 등장·오라)를 한꺼번에 받는다. [has]로 있는 파일만 요청.
  static Future<MonsterArt> load(Images images, String key, {bool Function(String)? has}) async {
    final dir = 'monsters/$key/$key';
    bool exists(String p) => has == null || has(p);
    final wantAppear = key.startsWith('boss-') && exists('$dir-appear.json');
    final wantAura = key == 'boss-zombie-king' && exists('$dir-aura.json');
    final r = await Future.wait([
      Sheet.load(images, '$dir-walk.json'),
      Sheet.load(images, '$dir-hit.json'),
      Sheet.load(images, '$dir-die.json'),
      if (wantAppear) Sheet.load(images, '$dir-appear.json'),
      if (wantAura) Sheet.load(images, '$dir-aura.json'),
    ]);
    var i = 3;
    return MonsterArt(
      r[0],
      r[1],
      r[2],
      wantAppear ? r[i++] : null,
      wantAura ? r[i++] : null,
    );
  }
}

class Monster extends PositionComponent with HasGameReference<MallangGame> {
  Monster({required this.round, required this.speed, this.boss = false, this.lane = 0})
      : maxHp = boss ? Rules.bossHp[Rules.stage(round)] : Rules.normalHp(round),
        defense = boss ? Rules.bossDefense[Rules.stage(round)] : Rules.normalDefense[Rules.stage(round)],
        super(
          size: (boss
                  ? (Rules.stage(round) == monsterKinds.length - 1 ? Vector2(96, 100) : Vector2(72, 76))
                  : Vector2(40, 44)) *
              (boss ? Rules.bossScale : Rules.mobScale),
          anchor: Anchor.bottomCenter,
          priority: boss ? 6 : 5,
        ) {
    hp = maxHp;
  }

  final int round;
  final double speed;

  /// 길 가운데에서 옆으로 비켜 걷는 거리 (2줄 걷기).
  final double lane;
  final bool boss;
  final double maxHp;
  final double defense;
  late double hp;
  bool dead = false;

  double traveled = 0;
  double _t = math.Random().nextDouble() * 3; // 걷기 박자가 모두 같지 않게
  double _age = 0;
  double _facing = 1;
  double _hitFlash = 0;

  String get artKey => monsterKey(Rules.stage(round), boss);
  MonsterArt? get _art => game.monsterArt[artKey];
  bool get flipped => _facing < 0;

  /// 보스 등장 동작이 끝나기 전에는 제자리에서 착지·포효한다.
  bool get _appearing {
    final a = _art?.appear;
    return a != null && _age < a.duration;
  }

  /// 몸 중심 (투사체가 날아갈 곳).
  Vector2 get hitPoint => position - Vector2(0, size.y * 0.45);

  @override
  void onMount() {
    super.onMount();
    _place();
  }

  @override
  void update(double dt) {
    _age += dt;
    _t += dt;
    if (_hitFlash > 0) _hitFlash -= dt;
    if (!_appearing) traveled += speed * dt;
    _place();
  }

  void _place() {
    final p = game.track.positionAt(traveled);
    final dir = game.track.directionAt(traveled);
    // 길 진행 방향의 옆으로 lane만큼 비켜 걷는다 (2줄)
    position.setValues(p.dx - dir.dy * lane, p.dy + dir.dx * lane + 12);
    final dx = dir.dx;
    if (dx.abs() > 0.2) _facing = dx > 0 ? 1 : -1;
  }

  /// 방어력을 적용해 피해를 준다. 실제로 들어간 피해를 돌려준다.
  double takeDamage(double raw) {
    if (dead) return 0;
    final dmg = Rules.mitigate(raw, defense);
    hp -= dmg;
    _hitFlash = 0.1;
    if (hp <= 0) {
      dead = true;
      game.killMonster(this);
    }
    return dmg;
  }

  /// 쓰러짐 동작 (몬스터가 사라진 자리에서 한 번 재생).
  Component? deathEffect() {
    final art = _art;
    if (art == null) return null;
    return MonsterDeath(art.die, position.clone(), flipped, priority, boss ? Rules.bossScale : Rules.mobScale);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final foot = Offset(w / 2, h);
    final ghost = Rules.stage(round) == 4;
    // 그림자 (떠다니는 귀신은 옅게)
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h - 2), width: w * 0.75, height: h * 0.16),
        Paint()..color = Color(ghost ? 0x22000000 : 0x40000000));

    final art = _art;
    if (art == null) {
      _drawPlaceholder(canvas);
    } else {
      // 그림은 발밑을 기준으로 크기 배율만큼 키워 그린다
      final k = boss ? Rules.bossScale : Rules.mobScale;
      canvas.save();
      canvas.translate(foot.dx, foot.dy);
      canvas.scale(k);
      canvas.translate(-foot.dx, -foot.dy);
      final aura = art.aura;
      if (aura != null) aura.draw(canvas, aura.frameAt(_t), foot, flip: flipped);
      final appear = art.appear;
      if (appear != null && _appearing) {
        appear.draw(canvas, appear.frameAt(_age, loop: false), foot, flip: flipped);
      } else if (_hitFlash > 0) {
        art.hit.draw(canvas, 0, foot, flip: flipped);
      } else {
        art.walk.draw(canvas, art.walk.frameAt(_t), foot, flip: flipped);
      }
      canvas.restore();
    }

    // 체력 막대 (보스는 항상, 일반은 맞았을 때만)
    if (boss || hp < maxHp) {
      final bw = boss ? 64.0 : 30.0;
      final top = boss ? -16.0 : -6.0;
      final bar = Rect.fromLTWH(w / 2 - bw / 2, top, bw, boss ? 7 : 4);
      canvas.drawRect(bar, Paint()..color = const Color(0xCC2A211C));
      canvas.drawRect(
          Rect.fromLTWH(bar.left + 1, bar.top + 1, (bar.width - 2) * math.max(0, hp) / maxHp,
              bar.height - 2),
          Paint()..color = const Color(0xFFE0483E));
    }
  }

  /// 그림을 못 불러왔을 때만 쓰는 임시 말랑이.
  void _drawPlaceholder(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final r = math.min(w, h) * 0.4;
    final c = Offset(w / 2, h - r);
    canvas.drawCircle(c, r, Paint()..color = _hitFlash > 0 ? const Color(0xFFFFFFFF) : const Color(0xFF8A6E4B));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFF2A211C));
  }
}

/// 몬스터가 쓰러진 자리에서 쓰러짐 동작을 한 번 재생하고 사라진다.
class MonsterDeath extends PositionComponent {
  MonsterDeath(this.sheet, Vector2 at, this.flip, int layer, [this.scale = 1])
      : super(position: at, anchor: Anchor.topLeft, priority: layer);

  final double scale;

  final Sheet sheet;
  final bool flip;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= sheet.duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(scale);
    sheet.draw(canvas, sheet.frameAt(_t, loop: false), Offset.zero, flip: flip);
    canvas.restore();
  }
}
