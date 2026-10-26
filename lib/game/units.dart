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
/// [onImpact]이면 투사체가 몬스터에 닿을 때 피해가 들어가고, 투사체는 움직이는 몬스터를 따라간다.
void fireAt(MallangGame game, String branch, double power, Vector2 from, List<Monster> targets,
    {bool shot = true, bool melee = false, bool onImpact = false}) {
  final st = Rules.stats[branch]!;
  for (final m in targets) {
    final crit = game.rng.nextDouble() < st.crit;
    final raw = st.atk * Rules.damageScale * power * (crit ? Rules.critMultiplier : 1);
    if (onImpact && shot && !melee) {
      game.world.add(Shot(from.clone(), m.hitPoint, branchColor(branch),
          aoe: st.aoe, target: m, onImpact: () => m.takeDamage(raw)));
      continue;
    }
    if (shot) game.world.add(Shot(melee ? m.hitPoint : from.clone(), m.hitPoint, branchColor(branch), aoe: st.aoe));
    m.takeDamage(raw);
  }
}

/// 막사: 보급병·돌아온 유닛을 보관하는 대기석 (막사 안 유닛은 공격하지 않음).
class Barracks extends PositionComponent with TapCallbacks, HasGameReference<MallangGame> {
  Barracks(this.branch, BuildingSpot spot)
      : super(
          position: Vector2(spot.foot.dx, spot.foot.dy),
          size: Vector2(spot.w, spot.h),
          anchor: Anchor.bottomCenter,
          priority: 3,
        );

  final String branch;
  final List<int> counts = [0, 0, 0, 0]; // 군졸, 정병, 군관, 장수
  late Still _still;
  late Sheet _enter;
  double _enterT = -1;

  /// 문 앞 (보급병이 들어가고 유닛이 나오는 자리).
  Offset get door => Offset(position.x, position.y - 4);

  int get total => counts.fold(0, (a, n) => a + n);

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
  }

  @override
  void onTapDown(TapDownEvent event) => game.openBarracks(branch);

  /// 막사 아래 등급별 인원: 군졸(흰 옷) · 정병(병과색) · 군관(어두운 갑주·은 테) · 장수(금 테).
  void _tierCounts(Canvas canvas, Offset center) {
    const r = 10.5;
    const gap = 24.0;
    final fills = [const Color(0xFFFFFFFF), branchColor(branch), const Color(0xFF4A4E54), branchColor(branch)];
    final rims = [_ink, _ink, const Color(0xFFC9CED6), const Color(0xFFF2C14E)];
    final inks = [_ink, const Color(0xFFFFFFFF), const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)];
    for (var t = 0; t < 4; t++) {
      final c = center + Offset((t - 1.5) * gap, 0);
      final empty = counts[t] == 0;
      canvas.drawCircle(c, r, Paint()..color = fills[t].withValues(alpha: empty ? 0.45 : 1));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = t >= 2 ? 2.2 : 1.4
            ..color = rims[t].withValues(alpha: empty ? 0.4 : 1));
      final tp = TextPainter(
        text: TextSpan(
          text: '${counts[t]}',
          style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
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

    final toBarracks = game.supplyToBarracks[branch] ?? false;
    final tp = TextPainter(
      text: TextSpan(
        text: toBarracks ? '$branch · 막사로' : branch,
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
    if (game.canSummonGeneral(branch)) {
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

/// 맵에 나와 싸우는 유닛 (군졸·정병·군관·장수).
/// 끌거나 '집기'로 옮기면 그 자리까지 걸어가고(처음) / 뛰어가며(이후), 이동 중에는 공격하지 않는다.
/// 누르면 상세 창이 열린다.
class FieldUnit extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<MallangGame> {
  FieldUnit(this.branch, this.tier, Vector2 at, {double delay = 0})
      : _wait = delay,
        super(position: at, size: Vector2(72, 84), anchor: const Anchor(0.5, 0.85), priority: 8);

  static const double walkSpeed = 160; // 처음 자리 잡으러 갈 때 (px/초)
  static const double runSpeed = 240; // 자리를 옮기거나 막사로 돌아갈 때

  final String branch;
  final int tier; // 0 군졸, 1 정병, 2 군관, 3 장수
  bool selected = false;
  double _wait; // 보급병: 출발 전 대기 (안 보임)
  double _cool = 0;
  double _t = 0;
  double _attackT = -1;
  bool _flip = false;
  bool _placedOnce = false;

  /// 막사로 돌아가는 중 (공격 안 함, 도착하면 막사 인원이 됨).
  bool returning = false;

  /// 공격 동작 중 무기를 내미는 프레임에서 쏠 대상 (그 프레임 전까지 대기).
  List<Monster>? _pending;
  double _releaseAt = 0;

  Vector2? _target;
  double _speed = walkSpeed;

  Vector2? _ghost;
  bool _ghostOk = true;

  bool get moving => _target != null;
  bool get visible => _wait <= 0;
  int get group => tier >= 3 ? 1 : 0; // 강화 묶음
  String get title => '$branch ${Rules.tierNames[tier]}';

  /// 다른 유닛과 겹침을 판단할 자리 (이동 중이면 목적지).
  Vector2 get restSpot => _target ?? position;

  /// 겹치지 않게 비워 둘 반지름 (장수는 크게).
  double get spacing => tier >= 3 ? 33 : 24;

  UnitArt? get art => game.fieldArt[branch]?[tier];

  double get radius => Rules.rangeRadius(branch);
  double get power => Rules.tierPower[tier] * game.atkMul(group);

  /// [target]까지 이동. [run]이면 뛰어서.
  void moveTo(Vector2 target, {bool? run}) {
    _speed = (run ?? _placedOnce) ? runSpeed : walkSpeed;
    _placedOnce = true;
    _target = target.clone();
    _attackT = -1;
    _pending = null;
  }

  /// 막사로 돌아가기: 막사 문까지 뛰어가서 들어간다.
  void sendHome() {
    final door = game.barracks[branch]!.door;
    returning = true;
    selected = false;
    moveTo(Vector2(door.dx, door.dy), run: true);
  }

  @override
  void update(double dt) {
    if (_wait > 0) {
      _wait -= dt;
      return;
    }
    _t += dt;
    final a = art;
    if (_attackT >= 0) {
      _attackT += dt;
      if (_pending != null && _attackT >= _releaseAt) _release();
      if (_attackT > (a?.attack?.duration ?? 0.18)) _attackT = -1;
    }
    final target = _target;
    if (target != null) {
      final d = target - position;
      final step = _speed * dt;
      if (d.length <= step) {
        position.setFrom(target);
        _target = null;
        if (returning) game.unitEntered(this);
      } else {
        if (d.x.abs() > 1) _flip = d.x < 0;
        position += d.normalized() * step;
      }
      return;
    }
    if (_ghost != null || returning) return;
    _cool -= dt;
    if (_cool > 0) return;
    final targets = game.monstersInRange(
        position, radius, Rules.stats[branch]!.aoe ? Rules.aoeTargets : 1);
    if (targets.isEmpty) return;
    _cool = 1 / (Rules.stats[branch]!.speed * game.speedMul(group));
    _flip = targets.first.position.x < position.x;
    final atk = a?.attack;
    if (atk == null) {
      _attackT = 0.0001; // 짧게 앞으로 튀는 동작
      fireAt(game, branch, power, position + Vector2(0, -24), targets);
      return;
    }
    _attackT = 0;
    _pending = targets;
    _releaseAt = _eventTime(atk);
  }

  /// 공격 시트에서 타격점·발사 지점이 있는 프레임이 시작되는 시각.
  static double _eventTime(Sheet s) {
    var t = 0.0;
    for (final f in s.frames) {
      if (f.hit != null || f.projectile != null) return t;
      t += f.seconds;
    }
    return 0;
  }

  /// 무기를 내민 프레임: 근접은 그 자리에서 타격, 원거리는 무기 끝에서 투사체가 나간다.
  void _release() {
    var targets = _pending!.where((m) => !m.dead && m.isMounted).toList();
    _pending = null;
    if (targets.isEmpty) {
      targets = game.monstersInRange(position, radius, Rules.stats[branch]!.aoe ? Rules.aoeTargets : 1);
      if (targets.isEmpty) return;
    }
    SheetFrame? ev;
    final atk = art?.attack;
    if (atk != null) {
      for (final f in atk.frames) {
        if (f.hit != null || f.projectile != null) {
          ev = f;
          break;
        }
      }
    }
    if (ev == null) {
      fireAt(game, branch, power, position + Vector2(0, -40), targets);
      return;
    }
    final melee = ev.hit != null;
    final p = (ev.hit ?? ev.projectile)!;
    final w = ev.src.width / artScale;
    final h = ev.src.height / artScale;
    var dx = p.dx / artScale - ev.anchor.dx * w;
    final dy = p.dy / artScale - ev.anchor.dy * h;
    if (_flip) dx = -dx;
    fireAt(game, branch, power, position + Vector2(dx, dy), targets, melee: melee, onImpact: true);
  }

  @override
  bool containsLocalPoint(Vector2 point) => visible && !returning && super.containsLocalPoint(point);

  @override
  void onTapUp(TapUpEvent event) => game.openDetail(this);

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
    game.placeUnit(this, g.toOffset());
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
    if (!visible) return;
    final ax = size.x / 2;
    final ay = size.y * 0.85;
    final color = branchColor(branch);
    final foot = Offset(ax, ay);
    final a = art;

    // 끄는 중: 놓을 자리에 사거리와 흐린 모습
    final ghost = _ghost;
    if (ghost != null) {
      final gf = foot + (ghost - position).toOffset();
      _drawRange(canvas, gf, _ghostOk, color);
      if (a != null) {
        canvas.saveLayer(null, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.45));
        a.idle.draw(canvas, 0, gf, flip: _flip);
        canvas.restore();
      } else {
        canvas.drawCircle(gf.translate(0, -20), 18, Paint()..color = color.withValues(alpha: 0.4));
      }
    } else if ((selected || game.heldUnit == this) && !moving) {
      _drawRange(canvas, foot, true, color);
    }

    // 이동 중: 목적지 표시 (막사로 돌아갈 때는 표시 안 함)
    final target = _target;
    if (target != null && !returning) {
      final tf = foot + (target - position).toOffset();
      canvas.drawOval(Rect.fromCenter(center: tf, width: 34, height: 12),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: 0.8));
    }

    // 막사 문에 가까워지면 서서히 사라짐 (들어가는 모습)
    var alpha = 1.0;
    if (returning && target != null) {
      final d = (target - position).length;
      alpha = (d / 40).clamp(0.0, 1.0);
    }
    if (alpha < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));

    // 집기 상태: 발밑에 금색 고리
    if (game.heldUnit == this) {
      canvas.drawOval(Rect.fromCenter(center: foot, width: 54, height: 18),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFF2C14E));
    }

    final hop = _hop;
    if (a != null) {
      final walk = a.walk;
      final run = _speed >= runSpeed;
      final atk = a.attack;
      if (moving && walk != null) {
        walk.draw(canvas, walk.frameAt(_t * (run ? 1.6 : 1)), foot, flip: _flip);
      } else if (_attackT >= 0 && atk != null) {
        atk.draw(canvas, atk.frameAt(_attackT, loop: false), foot, flip: _flip);
      } else {
        // 공격 시트가 없는 등급: 쏠 때 앞으로 살짝 튀어나옴
        final lunge = (_attackT >= 0 && _attackT < 0.18) ? math.sin(_attackT / 0.18 * math.pi) * 5 : 0.0;
        a.idle.draw(canvas, a.idle.frameAt(_t), foot.translate(_flip ? -lunge : lunge, -hop), flip: _flip);
      }
      if (alpha < 1) canvas.restore();
      return;
    }
    canvas.save();
    canvas.translate(0, -hop);
    final k = tier >= 3 ? 1.0 : 0.7;
    canvas.translate(ax * (1 - k), ay * (1 - k));
    canvas.scale(k);
    // 받침
    canvas.drawOval(Rect.fromCenter(center: Offset(ax, ay), width: 56, height: 14),
        Paint()..color = color.withValues(alpha: 0.55));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    final bob = math.sin(_t * 4) * 1.5;
    final body = Path()
      ..moveTo(ax - 22, ay - 2)
      ..quadraticBezierTo(ax - 26, ay - 40 + bob, ax, ay - 46 + bob)
      ..quadraticBezierTo(ax + 26, ay - 40 + bob, ax + 22, ay - 2)
      ..quadraticBezierTo(ax, ay + 3, ax - 22, ay - 2)
      ..close();
    canvas.drawPath(body, Paint()..color = tier == 0 ? const Color(0xFFF4F1EA) : color);
    canvas.drawPath(body, line);
    canvas.drawCircle(Offset(ax + 6, ay - 26 + bob), 3, Paint()..color = _ink);
    canvas.drawCircle(Offset(ax + 16, ay - 26 + bob), 3, Paint()..color = _ink);
    if (tier >= 2) {
      final helm = Path()
        ..moveTo(ax - 20, ay - 38 + bob)
        ..quadraticBezierTo(ax, ay - 62 + bob, ax + 20, ay - 38 + bob)
        ..close();
      canvas.drawPath(helm, Paint()..color = const Color(0xFF5C6066));
      canvas.drawPath(helm, line);
    }
    canvas.restore();
    if (alpha < 1) canvas.restore();
  }
}

/// 빈 땅 누르기 (집기로 들고 있을 때만 받음).
class PlaceCatcher extends PositionComponent with TapCallbacks, HasGameReference<MallangGame> {
  PlaceCatcher() : super(size: Vector2(Board.playWidth, Board.height), priority: 1);

  @override
  bool containsLocalPoint(Vector2 point) => game.heldUnit != null && super.containsLocalPoint(point);

  @override
  void onTapUp(TapUpEvent event) => game.tapGround(event.localPosition.toOffset());
}

/// 투사체. [target]이 있으면 날아가는 동안 몬스터를 따라가고, 닿을 때 [onImpact]로 피해가 들어간다.
class Shot extends PositionComponent {
  Shot(this.from, this.to, this.color, {this.aoe = false, this.target, this.onImpact}) : super(priority: 15);

  final Vector2 from;
  final Vector2 to;
  final Color color;
  final bool aoe;
  final Monster? target;
  void Function()? onImpact;
  double _t = 0;
  static const double _flight = 0.18;
  static const double _burst = 0.16;

  @override
  void update(double dt) {
    _t += dt;
    final m = target;
    if (m != null && !m.dead && _t < _flight) to.setFrom(m.hitPoint);
    if (_t >= _flight && onImpact != null) {
      final hit = onImpact!;
      onImpact = null;
      hit();
    }
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

/// 맵 유닛 그림 (대기·공격·걷기 시트).
class UnitArt {
  UnitArt(this.idle, this.attack, [this.walk]);
  final Sheet idle;

  /// 공격 시트 (군졸~군관은 아직 없음).
  final Sheet? attack;

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
