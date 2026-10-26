import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'board.dart';
import 'mallang_game.dart';
import 'rules.dart';

const _ink = Color(0xFF2A211C);

/// 오른쪽 반투명 패널 + 알림 글자.
class Hud extends PositionComponent with TapCallbacks, HasGameReference<MallangGame> {
  Hud()
      : super(
          position: Vector2(Board.playWidth, 0),
          size: Vector2(Board.width - Board.playWidth, Board.height),
          priority: 50,
        );

  static const _speedBtn = Rect.fromLTWH(12, 640, 132, 56);

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    if (_speedBtn.contains(event.localPosition.toOffset())) game.toggleSpeed();
  }

  void _text(Canvas c, String s, Offset at,
      {double size = 16, Color color = _ink, bool bold = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center ? at - Offset(tp.width / 2, 0) : at);
  }

  void _bar(Canvas c, double y, double ratio, Color color) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(12, y, 132, 10), const Radius.circular(5));
    c.drawRRect(r, Paint()..color = const Color(0x332A211C));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(12, y, 132 * ratio.clamp(0.0, 1.0), 10), const Radius.circular(5)),
        Paint()..color = color);
  }

  @override
  void render(Canvas canvas) {
    final g = game;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = const Color(0xA6FBF8F1));
    canvas.drawLine(const Offset(0, 0), Offset(0, size.y),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0x402A211C));

    _text(canvas, '라운드', const Offset(12, 14), size: 14);
    _text(canvas, '${g.round} / ${Rules.lastRound}', const Offset(12, 32), size: 30, bold: true);
    final left = (Rules.roundSeconds - g.roundTime).clamp(0, Rules.roundSeconds);
    _text(canvas, '다음 라운드 ${left.toStringAsFixed(1)}초', const Offset(12, 74), size: 13);
    _bar(canvas, 94, g.roundTime / Rules.roundSeconds, const Color(0xFF2E5E8C));

    final n = g.monsters.length;
    final danger = n >= 80;
    _text(canvas, '몬스터', const Offset(12, 124), size: 14);
    _text(canvas, '$n / ${Rules.loseCount}', const Offset(12, 142),
        size: 26, bold: true, color: danger ? const Color(0xFFC0392B) : _ink);
    _bar(canvas, 178, n / Rules.loseCount, danger ? const Color(0xFFC0392B) : const Color(0xFF8A6E4B));

    final boss = g.boss;
    if (boss != null && !boss.dead) {
      _text(canvas, '보스', const Offset(12, 206), size: 14, color: const Color(0xFF8C2F2B), bold: true);
      _text(canvas, '${(boss.hp).ceil()} / ${boss.maxHp.toInt()}', const Offset(12, 224), size: 15, bold: true);
      _bar(canvas, 246, boss.hp / boss.maxHp, const Color(0xFFE0483E));
      _text(canvas, '${left.toStringAsFixed(1)}초 안에 처치', const Offset(12, 262),
          size: 13, color: const Color(0xFF8C2F2B));
    }

    _text(canvas, '처치 ${g.kills}', const Offset(12, 300), size: 15);
    _text(canvas, '장수 ${g.generals.length}명', const Offset(12, 322), size: 15);

    _text(canvas, '막사를 누르면\n승진 · 장수 소환', const Offset(12, 560), size: 13, color: const Color(0xFF5C6066));

    final btn = RRect.fromRectAndRadius(_speedBtn, const Radius.circular(12));
    canvas.drawRRect(btn, Paint()..color = g.gameSpeed > 1 ? const Color(0xFF2E5E8C) : const Color(0xFFFFFFFF));
    canvas.drawRRect(
        btn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF2E5E8C));
    _text(canvas, '속도 ×${g.gameSpeed.toInt()}', Offset(_speedBtn.center.dx, _speedBtn.top + 15),
        size: 18, bold: true, center: true, color: g.gameSpeed > 1 ? const Color(0xFFFFFFFF) : const Color(0xFF2E5E8C));

    final t = g.toastText;
    if (t != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: const TextStyle(
              fontFamily: 'Pretendard', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final c = Offset(Board.playWidth / 2 - position.x, 668);
      final r = Rect.fromCenter(center: c, width: tp.width + 32, height: tp.height + 14);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), Paint()..color = const Color(0xE62A211C));
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }
}
