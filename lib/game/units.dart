import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'board.dart';
import 'mallang_game.dart';
import 'monster.dart';
import 'rules.dart';

const _ink = Color(0xFF2A211C);

Color branchColor(String branch) =>
    Board.branches.firstWhere((b) => b.name == branch).color;

/// 한 번 공격: 대상 고르기 → 피해 → 투사체 그림.
void fireAt(MallangGame game, String branch, double power, Vector2 from, List<Monster> targets) {
  final st = Rules.stats[branch]!;
  for (final m in targets) {
    final crit = game.rng.nextDouble() < st.crit;
    final raw = st.atk * Rules.damageScale * power * (crit ? Rules.critMultiplier : 1);
    game.world.add(Shot(from.clone(), m.hitPoint, branchColor(branch), aoe: st.aoe));
    m.takeDamage(raw);
  }
}

/// 막사: 안에 있는 군졸·정병·군관은 사거리 없이 선두 몬스터를 친다.
class Barracks extends PositionComponent with TapCallbacks, HasGameReference<MallangGame> {
  Barracks(this.branch, double x)
      : super(
          position: Vector2(x, Board.cy - 14),
          size: Vector2(100, 104),
          anchor: Anchor.center,
          priority: 3,
        );

  final String branch;
  final List<int> counts = [0, 0, 0]; // 군졸, 정병, 군관
  double _cool = 0;

  double get power {
    var p = 0.0;
    for (var t = 0; t < 3; t++) {
      p += counts[t] * Rules.tierPower[t];
    }
    return p;
  }

  int get total => counts[0] + counts[1] + counts[2];
  bool get canSummonGeneral => counts[0] > 0 && counts[1] > 0 && counts[2] > 0;

  @override
  void update(double dt) {
    if (total == 0) return;
    _cool -= dt;
    if (_cool > 0) return;
    final targets = game.leadMonsters(Rules.stats[branch]!.aoe ? Rules.aoeTargets : 1);
    if (targets.isEmpty) return;
    _cool = 1 / Rules.stats[branch]!.speed;
    fireAt(game, branch, power, position + Vector2(0, -30), targets);
  }

  @override
  void onTapDown(TapDownEvent event) => game.openBarracks(branch);

  @override
  void render(Canvas canvas) {
    if (total == 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: '${counts[0]} · ${counts[1]} · ${counts[2]}',
        style: const TextStyle(
            fontFamily: 'Pretendard', fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final c = Offset(size.x / 2, size.y + 8);
    final chip = Rect.fromCenter(center: c, width: tp.width + 14, height: tp.height + 2);
    canvas.drawRRect(RRect.fromRectAndRadius(chip, const Radius.circular(9)),
        Paint()..color = branchColor(branch));
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    if (canSummonGeneral) {
      canvas.drawCircle(Offset(size.x - 12, 14), 8, Paint()..color = const Color(0xFFF2C14E));
      canvas.drawCircle(
          Offset(size.x - 12, 14),
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _ink);
    }
  }
}

/// 맵에 놓인 장수. 끌어서 옮기고, 누르면 사거리가 보인다.
class General extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<MallangGame> {
  General(this.branch, Vector2 at)
      : super(position: at, size: Vector2(72, 84), anchor: const Anchor(0.5, 0.85), priority: 8);

  final String branch;
  bool showRange = false;
  double readyIn = 1.5;
  double _cool = 0;
  double _t = 0;
  Vector2? _home;
  bool _dragOk = true;

  double get radius => Rules.rangeRadius(branch);

  @override
  void update(double dt) {
    _t += dt;
    if (_home != null) return;
    if (readyIn > 0) {
      readyIn -= dt;
      return;
    }
    _cool -= dt;
    if (_cool > 0) return;
    final targets = game.monstersInRange(
        position, radius, Rules.stats[branch]!.aoe ? Rules.aoeTargets : 1);
    if (targets.isEmpty) return;
    _cool = 1 / Rules.stats[branch]!.speed;
    fireAt(game, branch, Rules.tierPower[3], position + Vector2(0, -40), targets);
  }

  @override
  void onTapUp(TapUpEvent event) {
    showRange = !showRange;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _home = position.clone();
    showRange = true;
    priority = 20;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    position += event.localDelta;
    _dragOk = game.canPlace(position.toOffset(), except: this);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final snapped = Vector2((position.x / 12).roundToDouble() * 12, (position.y / 12).roundToDouble() * 12);
    if (game.canPlace(snapped.toOffset(), except: this)) {
      position = snapped;
      readyIn = 1.5;
    } else {
      position = _home!;
      game.toast('길 · 궁 · 막사 · 다른 장수 위에는 놓을 수 없어요');
    }
    _home = null;
    _dragOk = true;
    showRange = false;
    priority = 8;
  }

  @override
  void render(Canvas canvas) {
    final ax = size.x / 2;
    final ay = size.y * 0.85;
    final color = branchColor(branch);

    if (showRange) {
      final ok = _dragOk;
      canvas.drawCircle(Offset(ax, ay), radius,
          Paint()..color = (ok ? color : const Color(0xFFE0483E)).withValues(alpha: 0.16));
      canvas.drawCircle(
          Offset(ax, ay),
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = (ok ? color : const Color(0xFFE0483E)).withValues(alpha: 0.7));
    }

    final notReady = readyIn > 0 || _home != null;
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
