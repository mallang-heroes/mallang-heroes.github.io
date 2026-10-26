import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'mallang_game.dart';
import 'rules.dart';

const _stageColors = [
  Color(0xFF8A6E4B),
  Color(0xFFC27A35),
  Color(0xFFB0565E),
  Color(0xFF5C7BA8),
  Color(0xFF9AA3AE),
  Color(0xFF6E8A5A),
];

/// 임시 몬스터 (그림 리소스가 나오기 전까지 코드로 그린 말랑이).
class Monster extends PositionComponent with HasGameReference<MallangGame> {
  Monster({required this.round, required this.speed, this.boss = false})
      : maxHp = boss ? Rules.bossHp[Rules.stage(round)] : Rules.normalHp(round),
        defense = boss ? Rules.bossDefense[Rules.stage(round)] : Rules.normalDefense[Rules.stage(round)],
        super(
          size: boss ? Vector2(72, 76) : Vector2(40, 44),
          anchor: Anchor.bottomCenter,
          priority: boss ? 6 : 5,
        ) {
    hp = maxHp;
  }

  final int round;
  final double speed;
  final bool boss;
  final double maxHp;
  final double defense;
  late double hp;
  bool dead = false;

  double traveled = 0;
  double _t = math.Random().nextDouble() * 3;
  double _facing = 1;
  double _hitFlash = 0;

  Color get _color => boss ? const Color(0xFF8C2F2B) : _stageColors[Rules.stage(round)];

  /// 몸 중심 (투사체가 날아갈 곳).
  Vector2 get hitPoint => position - Vector2(0, size.y * 0.45);

  @override
  void onMount() {
    super.onMount();
    _place();
  }

  @override
  void update(double dt) {
    traveled += speed * dt;
    _t += dt;
    if (_hitFlash > 0) _hitFlash -= dt;
    _place();
  }

  void _place() {
    final p = game.track.positionAt(traveled);
    position.setValues(p.dx, p.dy + 12);
    final dx = game.track.directionAt(traveled).dx;
    if (dx.abs() > 0.2) _facing = dx > 0 ? 1 : -1;
  }

  /// 방어력을 적용해 피해를 준다. 실제로 들어간 피해를 돌려준다.
  double takeDamage(double raw) {
    if (dead) return 0;
    final dmg = Rules.mitigate(raw, defense);
    hp -= dmg;
    _hitFlash = 0.08;
    if (hp <= 0) {
      dead = true;
      game.killMonster(this);
    }
    return dmg;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h - 2), width: w * 0.75, height: h * 0.18),
        Paint()..color = const Color(0x40000000));

    final squash = 1 + 0.07 * math.sin(_t * 11);
    final k = boss ? 1.8 : 1.0;
    canvas.save();
    canvas.translate(w / 2, h);
    canvas.scale(_facing * (2 - squash) * k, squash * k);

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / k
      ..color = const Color(0xFF2A211C);
    final body = Path()
      ..moveTo(-17, -3)
      ..quadraticBezierTo(-19, -24, -6, -33)
      ..quadraticBezierTo(4, -38, 13, -30)
      ..quadraticBezierTo(20, -20, 17, -3)
      ..quadraticBezierTo(0, 1, -17, -3)
      ..close();
    canvas.drawPath(body, Paint()..color = _hitFlash > 0 ? const Color(0xFFFFFFFF) : _color);
    canvas.drawPath(
        Path()
          ..moveTo(-12, -26)
          ..quadraticBezierTo(-8, -32, -2, -32),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x66FFFFFF));
    canvas.drawPath(body, ink);

    // 뿔
    final horn = Path()
      ..moveTo(-1, -34)
      ..lineTo(4, -44)
      ..lineTo(7, -32)
      ..close();
    canvas.drawPath(horn, Paint()..color = const Color(0xFFE3C77A));
    canvas.drawPath(horn, ink);

    // 눈
    final white = Paint()..color = const Color(0xFFFFFFFF);
    final dark = Paint()..color = const Color(0xFF2A211C);
    canvas.drawCircle(const Offset(8, -20), 5, white);
    canvas.drawCircle(const Offset(8, -20), 5, ink);
    canvas.drawCircle(const Offset(9.5, -20), 2.4, dark);
    canvas.drawCircle(const Offset(-3, -20), 4, white);
    canvas.drawCircle(const Offset(-3, -20), 4, ink);
    canvas.drawCircle(const Offset(-1.8, -20), 2, dark);
    canvas.drawLine(const Offset(2, -11), const Offset(9, -12), ink);

    if (boss) {
      final crown = Path()
        ..moveTo(-8, -36)
        ..lineTo(-7, -46)
        ..lineTo(-3, -41)
        ..lineTo(0, -48)
        ..lineTo(3, -41)
        ..lineTo(7, -46)
        ..lineTo(8, -36)
        ..close();
      canvas.drawPath(crown, Paint()..color = const Color(0xFFF2C14E));
      canvas.drawPath(crown, ink);
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
}
