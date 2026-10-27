import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/cache.dart';
import 'package:flutter/painting.dart';

import 'effects.dart';
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
  final Sheet hit; // 맞을 때 아야 얼굴 1프레임 (번쩍임·밀림은 코드에서)
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

  // 맞을 때 연출: 하얗게 번쩍 → 아야 얼굴, 뒤로 밀렸다 돌아옴, 눌림, 걷기 잠깐 멈춤(히트스톱)
  double _hitAge = 9; // 마지막으로 맞은 뒤 지난 시간
  double _white = 0.05; // 완전히 하얀 시간
  double _freeze = 0; // 걷기 그림을 멈춰 둘 남은 시간
  double _knockAmp = 0; // 뒤로 밀리는 거리 (px)
  double _squashAmp = 0;
  Offset _dir = const Offset(1, 0); // 길 진행 방향
  static const double _hurtTime = 0.22;

  // 발 먼지
  final List<DustPuff> _dust = [];
  int _step = -1;

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
    if (_freeze > 0) {
      _freeze -= dt;
    } else {
      _t += dt;
    }
    _hitAge += dt;
    if (!_appearing) traveled += speed * dt;
    _place();
    _updateDust(dt);
  }

  /// 발이 땅에 닿을 때(걷기 한 바퀴에 두 번) 작은 먼지. 떠다니는 귀신과 등장 중인 보스는 없음.
  void _updateDust(double dt) {
    for (final d in _dust) {
      d.t += dt;
    }
    _dust.removeWhere((d) => d.t > DustPuff.life);
    final walk = _art?.walk;
    if (walk == null || _appearing || Rules.stage(round) == 4) return;
    final step = (_t / (walk.duration / 2)).floor();
    if (step != _step) {
      if (_step >= 0 && _dust.length < 4) {
        final foot = Offset(position.x - _dir.dx * size.x * 0.15, position.y - _dir.dy * size.x * 0.15); // size는 이미 배율 반영
        _dust.add(DustPuff(foot, -_dir, boss ? 1.6 * Rules.bossScale : Rules.mobScale));
      }
      _step = step;
    }
  }

  /// 뒤로 밀린 거리: 빠르게 밀렸다가 살짝 넘치며 돌아온다.
  double get _knock {
    if (_hitAge < 0.05) return -_knockAmp * _hitAge / 0.05;
    final t = _hitAge - 0.05;
    return -_knockAmp * math.exp(-12 * t) * math.cos(10 * t);
  }

  double get _squash => _squashAmp * math.exp(-14 * _hitAge) * math.cos(26 * _hitAge);

  void _place() {
    final p = game.track.positionAt(traveled);
    final dir = game.track.directionAt(traveled);
    _dir = dir;
    // 길 진행 방향의 옆으로 lane만큼 비켜 걷는다 (2줄)
    position.setValues(p.dx - dir.dy * lane, p.dy + dir.dx * lane + 12);
    final dx = dir.dx;
    if (dx.abs() > 0.2) _facing = dx > 0 ? 1 : -1;
  }

  /// 방어력을 적용해 피해를 준다. 실제로 들어간 피해를 돌려준다.
  /// [crit]이면 번쩍임·밀림·숫자가 더 크다.
  double takeDamage(double raw, {bool crit = false}) {
    if (dead) return 0;
    final dmg = Rules.mitigate(raw, defense);
    hp -= dmg;
    _hitAge = 0;
    _white = crit ? 0.07 : 0.05;
    _freeze = crit ? 0.09 : 0.06;
    _knockAmp = (crit ? 6.0 : 4.0) * (boss ? 0.5 : 1.0);
    _squashAmp = crit ? 0.14 : 0.1;
    game.world.add(HitSpark(hitPoint, crit: crit, big: boss));
    game.world.add(DamageText(math.max(1, dmg.round()), position - Vector2(0, size.y * 0.8), crit: crit));
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

    // 발 먼지 (보드 좌표 → 이 컴포넌트 안 좌표)
    final toLocal = foot - Offset(position.x, position.y);
    for (final d in _dust) {
      d.draw(canvas, toLocal);
    }

    // 맞았을 때: 길 반대쪽으로 밀리고 발밑 기준으로 눌림
    final kb = _knock;
    final sq = _squash;
    canvas.save();
    canvas.translate(foot.dx + _dir.dx * kb, foot.dy + _dir.dy * kb);
    canvas.scale(1 + sq, 1 - sq);
    canvas.translate(-foot.dx, -foot.dy);
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
      final paint = _hitPaint();
      final appear = art.appear;
      if (appear != null && _appearing) {
        appear.draw(canvas, appear.frameAt(_age, loop: false), foot, flip: flipped, paint: paint);
      } else if (_hitAge < _hurtTime) {
        art.hit.draw(canvas, 0, foot, flip: flipped, paint: paint);
      } else {
        art.walk.draw(canvas, art.walk.frameAt(_t), foot, flip: flipped);
      }
      canvas.restore();
    }
    canvas.restore();

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

  static final Paint _whitePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);

  /// 맞은 직후: 완전히 하얀 실루엣 → 하얀 기가 서서히 빠짐. 평소에는 null.
  Paint? _hitPaint() {
    if (_hitAge < _white) return _whitePaint;
    final a = 0.55 * (1 - (_hitAge - _white) / 0.15);
    if (a <= 0) return null;
    return Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(Color.fromRGBO(255, 255, 255, a), BlendMode.srcATop);
  }

  /// 그림을 못 불러왔을 때만 쓰는 임시 말랑이.
  void _drawPlaceholder(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final r = math.min(w, h) * 0.4;
    final c = Offset(w / 2, h - r);
    canvas.drawCircle(c, r, Paint()..color = _hitAge < 0.1 ? const Color(0xFFFFFFFF) : const Color(0xFF8A6E4B));
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
  MonsterDeath(this.sheet, Vector2 at, this.flip, int layer, [this.artMul = 1])
      : super(position: at, anchor: Anchor.topLeft, priority: layer);

  final double artMul; // 그림 크기 배율

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
    canvas.scale(artMul);
    sheet.draw(canvas, sheet.frameAt(_t, loop: false), Offset.zero, flip: flip);
    canvas.restore();
  }
}
