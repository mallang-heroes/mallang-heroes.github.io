import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'board.dart';
import 'mallang_game.dart';
import 'monster.dart';
import 'rules.dart';
import 'sheets.dart';

const _ink = Color(0xFF2A211C);

Color branchColor(String branch) => Board.branch(branch).color;

/// 슬라임 그림이 준비된 병과 (assets/images/units/<key>/<tier>/).
const slimeBranches = {'spear', 'archer', 'gunner', 'cavalry', 'navy', 'mystic'};

/// 막사 등급 그림 경로 (없으면 null).
String? tierImagePath(String branch, int tier) {
  final key = Board.branch(branch).key;
  if (!slimeBranches.contains(key)) return null;
  const tiers = ['gunjol', 'jeongbyeong', 'gungwan', 'jangsu'];
  return 'assets/images/units/$key/${tiers[tier]}/unit-$key-${tiers[tier]}.png';
}

/// 한 번 공격: 대상 고르기 → 피해 → 투사체 그림.
void fireAt(MallangGame game, String branch, double power, Vector2 from, List<Monster> targets,
    {bool shot = true, bool melee = false}) {
  final st = Rules.stats[branch]!;
  for (final m in targets) {
    final crit = game.rng.nextDouble() < st.crit;
    final raw = st.atk * Rules.damageScale * power * (crit ? Rules.critMultiplier : 1);
    if (shot) game.world.add(Shot(melee ? m.hitPoint : from.clone(), m.hitPoint, branchColor(branch), aoe: st.aoe));
    m.takeDamage(raw);
  }
}

/// 막사: 안에 있는 군졸·정병·군관은 사거리 없이 선두 몬스터를 친다.
class Barracks extends PositionComponent with TapCallbacks, HasGameReference<MallangGame> {
  Barracks(this.branch, BuildingSpot spot)
      : super(
          position: Vector2(spot.foot.dx, spot.foot.dy),
          size: Vector2(spot.w, spot.h),
          anchor: Anchor.bottomCenter,
          priority: 3,
        );

  final String branch;
  final List<int> counts = [0, 0, 0]; // 군졸, 정병, 군관
  double _cool = 0;
  late Still _still;
  late Sheet _enter;
  double _enterT = -1;

  double get power {
    var p = 0.0;
    for (var t = 0; t < 3; t++) {
      p += counts[t] * Rules.tierPower[t];
    }
    return p;
  }

  int get total => counts[0] + counts[1] + counts[2];
  bool get canSummonGeneral => counts[0] > 0 && counts[1] > 0 && counts[2] > 0;

  /// 병사가 들어올 때 건물이 들썩인다.
  void bounce() => _enterT = 0;

  @override
  Future<void> onLoad() async {
    final key = Board.branch(branch).key;
    _still = await Still.load(game.images, 'map/map-bld-barracks-$key.png');
    _enter = await Sheet.load(game.images, 'map/map-bld-barracks-$key-enter.json');
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= -8 && point.x <= size.x + 8 && point.y >= -8 && point.y <= size.y + 50;

  @override
  void update(double dt) {
    if (_enterT >= 0) {
      _enterT += dt;
      if (_enterT > _enter.duration) _enterT = -1;
    }
    if (total == 0) return;
    _cool -= dt;
    if (_cool > 0) return;
    final targets = game.leadMonsters(Rules.stats[branch]!.aoe ? Rules.aoeTargets : 1);
    if (targets.isEmpty) return;
    _cool = 1 / (Rules.stats[branch]!.speed * game.speedMul(0));
    fireAt(game, branch, power * game.atkMul(0), position + Vector2(0, -size.y * 0.6), targets);
  }

  @override
  void onTapDown(TapDownEvent event) => game.openBarracks(branch);

  /// 막사 아래 등급별 인원: 군졸(흰 옷) · 정병(병과색) · 군관(어두운 갑주·은 테).
  void _tierCounts(Canvas canvas, Offset center) {
    const r = 11.0;
    const gap = 26.0;
    final fills = [const Color(0xFFFFFFFF), branchColor(branch), const Color(0xFF4A4E54)];
    final rims = [_ink, _ink, const Color(0xFFC9CED6)];
    final inks = [_ink, const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)];
    for (var t = 0; t < 3; t++) {
      final c = center + Offset((t - 1) * gap, 0);
      final empty = counts[t] == 0;
      canvas.drawCircle(c, r, Paint()..color = fills[t].withValues(alpha: empty ? 0.45 : 1));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = t == 2 ? 2 : 1.4
            ..color = rims[t].withValues(alpha: empty ? 0.4 : 1));
      final tp = TextPainter(
        text: TextSpan(
          text: '${counts[t]}',
          style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: inks[t].withValues(alpha: empty ? 0.5 : 1)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  void render(Canvas canvas) {
    final foot = Offset(size.x / 2, size.y);
    if (_enterT >= 0) {
      _enter.draw(canvas, _enter.frameAt(_enterT, loop: false), foot);
    } else {
      _still.draw(canvas, foot);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: branch,
        style: const TextStyle(
            fontFamily: 'Pretendard', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final c = Offset(size.x / 2, size.y + 13);
    final chip = Rect.fromCenter(center: c, width: tp.width + 14, height: tp.height + 2);
    canvas.drawRRect(RRect.fromRectAndRadius(chip, const Radius.circular(9)),
        Paint()..color = branchColor(branch));
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    _tierCounts(canvas, Offset(size.x / 2, size.y + 36));
    if (canSummonGeneral) {
      final dot = Offset(size.x - 4, 6);
      canvas.drawCircle(dot, 8, Paint()..color = const Color(0xFFF2C14E));
      canvas.drawCircle(
          dot,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _ink);
    }
  }
}

/// 맵에 놓인 장수. 끌어서 놓으면 그 자리까지 걸어가고(처음) / 뛰어가고(이후), 누르면 사거리가 보인다.
class General extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<MallangGame> {
  General(this.branch, Vector2 at)
      : super(position: at, size: Vector2(72, 84), anchor: const Anchor(0.5, 0.85), priority: 8);

  static const double walkSpeed = 160; // 소환 후 첫 자리로 걸어갈 때 (px/초)
  static const double runSpeed = 240; // 자리를 옮길 때

  final String branch;
  bool showRange = false;
  double _cool = 0;
  double _t = 0;
  double _attackT = -1;
  bool _flip = false;
  bool _placedOnce = false;

  /// 이동 중이면 목적지 (이동 중에는 공격하지 않음).
  Vector2? _target;
  double _speed = walkSpeed;

  /// 끄는 중인 놓을 자리 미리보기.
  Vector2? _ghost;
  bool _ghostOk = true;

  bool get moving => _target != null;

  /// 다른 장수와 겹침을 판단할 자리 (이동 중이면 목적지).
  Vector2 get restSpot => _target ?? position;

  /// 그림 리소스가 있는 병과는 시트로, 없으면 코드로 그린다.
  UnitArt? get _art => game.unitArt[branch];

  double get radius => Rules.rangeRadius(branch);

  @override
  void update(double dt) {
    _t += dt;
    final art = _art;
    if (_attackT >= 0) {
      _attackT += dt;
      if (art == null || _attackT > art.attack.duration) _attackT = -1;
    }
    final target = _target;
    if (target != null) {
      final d = target - position;
      final step = _speed * dt;
      if (d.length <= step) {
        position.setFrom(target);
        _target = null;
      } else {
        if (d.x.abs() > 1) _flip = d.x < 0;
        position += d.normalized() * step;
      }
      return;
    }
    if (_ghost != null) return;
    _cool -= dt;
    if (_cool > 0) return;
    final targets = game.monstersInRange(
        position, radius, Rules.stats[branch]!.aoe ? Rules.aoeTargets : 1);
    if (targets.isEmpty) return;
    _cool = 1 / (Rules.stats[branch]!.speed * game.speedMul(1));
    _flip = targets.first.position.x < position.x;
    _attackT = 0;
    fireAt(game, branch, Rules.tierPower[3] * game.atkMul(1), position + Vector2(0, -40), targets,
        melee: art != null && branch == '창병');
  }

  @override
  void onTapUp(TapUpEvent event) {
    showRange = !showRange;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _ghost = restSpot.clone();
    _ghostOk = true;
    priority = 20;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final g = _ghost;
    if (g == null) return;
    g.add(event.localDelta);
    _ghostOk = game.canPlace(g.toOffset(), except: this);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final g = _ghost;
    _ghost = null;
    priority = 8;
    if (g == null) return;
    final snapped = Vector2((g.x / 12).roundToDouble() * 12, (g.y / 12).roundToDouble() * 12);
    if (!game.canPlace(snapped.toOffset(), except: this)) {
      game.toast('길 · 궁 · 막사 · 다른 장수 위에는 놓을 수 없어요');
      return;
    }
    if ((snapped - position).length < 2) return;
    _speed = _placedOnce ? runSpeed : walkSpeed;
    _placedOnce = true;
    _target = snapped;
    _attackT = -1;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _ghost = null;
    priority = 8;
  }

  /// 이동 중 통통 뛰는 높이.
  double get _hop {
    if (!moving) return 0;
    final run = _speed >= runSpeed;
    return (math.sin(_t * (run ? 18 : 12))).abs() * (run ? 7 : 5);
  }

  void _drawRange(Canvas canvas, Offset c, bool ok, Color color) {
    final col = ok ? color : const Color(0xFFE0483E);
    canvas.drawCircle(c, radius, Paint()..color = col.withValues(alpha: 0.16));
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = col.withValues(alpha: 0.7));
  }

  @override
  void render(Canvas canvas) {
    final ax = size.x / 2;
    final ay = size.y * 0.85;
    final color = branchColor(branch);
    final foot = Offset(ax, ay);

    // 끄는 중: 놓을 자리에 사거리와 흐린 모습
    final ghost = _ghost;
    if (ghost != null) {
      final gf = foot + (ghost - position).toOffset();
      _drawRange(canvas, gf, _ghostOk, color);
      final art = _art;
      if (art != null) {
        canvas.saveLayer(null, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.45));
        art.idle.draw(canvas, 0, gf, flip: _flip);
        canvas.restore();
      } else {
        canvas.drawCircle(gf.translate(0, -20), 18, Paint()..color = color.withValues(alpha: 0.4));
      }
    } else if (showRange && !moving) {
      _drawRange(canvas, foot, true, color);
    }

    // 이동 중: 목적지 표시
    final target = _target;
    if (target != null) {
      final tf = foot + (target - position).toOffset();
      canvas.drawOval(Rect.fromCenter(center: tf, width: 34, height: 12),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: 0.8));
    }

    final hop = _hop;
    final art = _art;
    if (art != null) {
      final walk = art.walk;
      final run = _speed >= runSpeed;
      if (moving && walk != null) {
        walk.draw(canvas, walk.frameAt(_t * (run ? 1.6 : 1)), foot, flip: _flip);
      } else if (_attackT >= 0) {
        art.attack.draw(canvas, art.attack.frameAt(_attackT, loop: false), foot, flip: _flip);
      } else {
        art.idle.draw(canvas, art.idle.frameAt(_t), foot.translate(0, -hop), flip: _flip);
      }
      return;
    }
    const notReady = false;
    canvas.save();
    canvas.translate(0, -hop);
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, notReady ? 0.55 : 1));
    // 받침
    canvas.drawOval(Rect.fromCenter(center: Offset(ax, ay), width: 56, height: 14),
        Paint()..color = color.withValues(alpha: 0.55));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    final bob = math.sin(_t * 4) * 1.5;
    // 몸 (말랑한 방울)
    final body = Path()
      ..moveTo(ax - 22, ay - 2)
      ..quadraticBezierTo(ax - 26, ay - 40 + bob, ax, ay - 46 + bob)
      ..quadraticBezierTo(ax + 26, ay - 40 + bob, ax + 22, ay - 2)
      ..quadraticBezierTo(ax, ay + 3, ax - 22, ay - 2)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(body, line);
    // 얼굴
    canvas.drawCircle(Offset(ax + 6, ay - 26 + bob), 3, Paint()..color = _ink);
    canvas.drawCircle(Offset(ax + 16, ay - 26 + bob), 3, Paint()..color = _ink);
    canvas.drawCircle(Offset(ax + 7, ay - 27 + bob), 1, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(Offset(ax + 17, ay - 27 + bob), 1, Paint()..color = const Color(0xFFFFFFFF));
    // 투구
    final helm = Path()
      ..moveTo(ax - 20, ay - 38 + bob)
      ..quadraticBezierTo(ax, ay - 62 + bob, ax + 20, ay - 38 + bob)
      ..close();
    canvas.drawPath(helm, Paint()..color = const Color(0xFF5C6066));
    canvas.drawPath(helm, line);
    canvas.drawRect(Rect.fromLTWH(ax - 22, ay - 40 + bob, 44, 4), Paint()..color = const Color(0xFFE3C77A));
    canvas.drawLine(Offset(ax, ay - 50 + bob), Offset(ax, ay - 64 + bob),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0xFFC2483F));
    canvas.restore();
    canvas.restore();

    // 병과 이름
    final tp = TextPainter(
      text: TextSpan(
        text: branch,
        style: TextStyle(
            fontFamily: 'Pretendard', fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final chip = Rect.fromCenter(center: Offset(ax, ay + 9), width: tp.width + 10, height: tp.height);
    canvas.drawRRect(RRect.fromRectAndRadius(chip, const Radius.circular(5)),
        Paint()..color = const Color(0xEEFBF8F1));
    tp.paint(canvas, Offset(ax - tp.width / 2, ay + 9 - tp.height / 2));
  }
}

/// 투사체 (피해는 쏠 때 바로 들어가고, 그림만 날아간다).
class Shot extends PositionComponent {
  Shot(this.from, this.to, this.color, {this.aoe = false}) : super(priority: 15);

  final Vector2 from;
  final Vector2 to;
  final Color color;
  final bool aoe;
  double _t = 0;
  static const double _flight = 0.18;
  static const double _burst = 0.16;

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _flight + _burst) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_t < _flight) {
      final k = _t / _flight;
      final p = from + (to - from) * k;
      final tail = from + (to - from) * math.max(0, k - 0.25);
      canvas.drawLine(tail.toOffset(), p.toOffset(),
          Paint()
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: 0.85));
      canvas.drawCircle(p.toOffset(), 3.5, Paint()..color = color);
    } else {
      final k = (_t - _flight) / _burst;
      canvas.drawCircle(to.toOffset(), (aoe ? 16 : 9) * (0.5 + k),
          Paint()..color = (aoe ? const Color(0xFFF2C14E) : const Color(0xFFFFFFFF)).withValues(alpha: (1 - k) * 0.8));
    }
  }
}

/// 위로 떠오르며 사라지는 글자 (+4 같은 보급 표시).
class FloatText extends PositionComponent {
  FloatText(this.text, Vector2 at, this.color) : super(position: at, priority: 30);

  final String text;
  final Color color;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    position.y -= 26 * dt;
    if (_t > 1.2) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1 - _t / 1.2).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: a),
          shadows: [Shadow(color: const Color(0xFF000000).withValues(alpha: a * 0.6), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

/// 병과 장수 그림 (대기·공격 시트).
class UnitArt {
  UnitArt(this.idle, this.attack, [this.walk]);
  final Sheet idle;
  final Sheet attack;

  /// 걷기 시트가 있으면 이동할 때 사용 (없으면 대기 그림으로 통통 뛰며 이동).
  final Sheet? walk;
}

/// 보급병: 궁에서 나와 자기 막사까지 걸어간 뒤 막사 인원이 된다.
class SupplyWalker extends PositionComponent with HasGameReference<MallangGame> {
  SupplyWalker(this.branch, this.tier, this.from, this.to, double delay)
      : _t = -delay,
        super(priority: 4);

  final String branch;
  final int tier;
  final Offset from;
  final Offset to;
  double _t;
  static const double duration = 1.4;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) {
      game.supplyArrived(this);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_t < 0) return;
    final k = (_t / duration).clamp(0.0, 1.0);
    final e = k < 0.5 ? 2 * k * k : 1 - (-2 * k + 2) * (-2 * k + 2) / 2; // ease-in-out
    final p = Offset.lerp(from, to, e)!;
    final alpha = k < 0.1 ? k / 0.1 : (k > 0.85 ? (1 - k) / 0.15 : 1.0);
    final flip = to.dx < from.dx;
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)));
    final sheet = game.tierWalk[branch]?[tier];
    if (sheet != null) {
      sheet.draw(canvas, sheet.frameAt(_t), p, flip: flip);
    } else {
      final bob = math.sin(_t * 14).abs() * 3;
      final body = Rect.fromCenter(center: p.translate(0, -12 - bob), width: 24, height: 20);
      canvas.drawOval(body, Paint()..color = branchColor(branch));
      canvas.drawOval(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _ink);
    }
    canvas.restore();
  }
}
