import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'mallang_game.dart';

/// 엽전 (은냥): 은빛 동전 + 가운데 네모 구멍.
void drawYeopjeon(Canvas c, Offset p, double r, {double alpha = 1}) {
  Color a(Color col) => col.withValues(alpha: col.a * alpha);
  c.drawCircle(p.translate(0, r * 0.18), r, Paint()..color = a(const Color(0x55000000)));
  c.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [a(const Color(0xFFF7F9FB)), a(const Color(0xFFC3C9D2)), a(const Color(0xFF8C939E))],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: p, radius: r)));
  c.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.14)
        ..color = a(const Color(0xFF6E7580)));
  c.drawCircle(
      p,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.07)
        ..color = a(const Color(0x996E7580)));
  final h = r * 0.34;
  c.drawRect(Rect.fromCenter(center: p, width: h * 2, height: h * 2), Paint()..color = a(const Color(0xFF59606B)));
  c.drawRect(
      Rect.fromCenter(center: p, width: h * 2, height: h * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.08)
        ..color = a(const Color(0xFFE7EBF0)));
}

/// 몬스터를 잡으면 그 자리에서 엽전이 튀어 올랐다가 위쪽 정보줄의 은냥 칸으로 날아간다.
class CoinFly extends PositionComponent with HasGameReference<MallangGame> {
  CoinFly(this.from, this.amount) : super(priority: 60);

  final Offset from;
  final int amount;
  double _t = 0;
  static const double _pop = 0.28;
  static const double _fly = 0.55;

  /// 화면 위 정보줄의 은냥 칸 (보드 좌표, 대략).
  static const Offset target = Offset(430, 92);
  Offset get _target => target;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= _pop + _fly) {
      game.coinArrived(amount);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    Offset p;
    double r = 9;
    if (_t < _pop) {
      final k = _t / _pop;
      p = from.translate(0, -34 * math.sin(k * math.pi * 0.5) + 6 * k * k);
      // 처음 튀어 오를 때 숫자 함께
      final tp = TextPainter(
        text: TextSpan(
          text: '+$amount',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF4F6F9).withValues(alpha: 1 - k * 0.3),
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p.translate(12, -tp.height / 2 - 2));
    } else {
      final k = ((_t - _pop) / _fly).clamp(0.0, 1.0);
      final e = k * k * (3 - 2 * k);
      final start = from.translate(0, -28);
      final mid = Offset((start.dx + _target.dx) / 2, math.min(start.dy, _target.dy) - 120);
      // 2차 베지어 곡선으로 휘어 날아감
      final a = Offset.lerp(start, mid, e)!;
      final b = Offset.lerp(mid, _target, e)!;
      p = Offset.lerp(a, b, e)!;
      r = 9 - 2 * e;
    }
    // 반짝 꼬리
    canvas.drawCircle(p, r + 4, Paint()..color = const Color(0x33FFFFFF));
    drawYeopjeon(canvas, p, r);
  }
}
