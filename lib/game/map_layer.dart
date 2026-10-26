import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'board.dart';

const _ink = Color(0xFF2A211C);

/// 움직이지 않는 맵(바닥·길·궁·막사)을 한 번만 그려 이미지로 두고 매 프레임 그대로 찍는다.
class MapLayer extends PositionComponent {
  MapLayer() : super(size: Vector2(Board.width, Board.height), priority: 0);

  ui.Image? _image;

  @override
  Future<void> onLoad() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paint(canvas);
    final picture = recorder.endRecording();
    _image = await picture.toImage(Board.width.toInt(), Board.height.toInt());
    picture.dispose();
  }

  @override
  void render(Canvas canvas) {
    final img = _image;
    if (img != null) canvas.drawImage(img, Offset.zero, Paint());
  }

  static void _paint(Canvas canvas) {
    // 바닥
    canvas.drawRect(const Rect.fromLTWH(0, 0, Board.width, Board.height),
        Paint()..color = const Color(0xFFB9C59E));
    final dotA = Paint()..color = const Color(0x2E465A32);
    for (var y = 0.0; y < Board.height; y += 22) {
      for (var x = 0.0; x < Board.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 1.3, dotA);
      }
    }
    final dotB = Paint()..color = const Color(0x2EFFFFE6);
    for (var y = 7.0; y < Board.height; y += 31) {
      for (var x = 11.0; x < Board.width; x += 31) {
        canvas.drawCircle(Offset(x, y), 1.1, dotB);
      }
    }

    // 길
    final spur = Board.spur;
    final loop = Board.loop;
    for (final (w, c) in const [
      (54.0, Color(0xFF7A6446)),
      (46.0, Color(0xFFC3A678)),
      (28.0, Color(0xFFCFB487)),
    ]) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = c;
      canvas.drawPath(loop, p);
      canvas.drawPath(spur, p..strokeCap = StrokeCap.round);
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFA88B5F);
    canvas.drawPath(
        _dashed(Board.roundedLoop(Board.vertices(-17), Board.cornerRadius - 10), 14, 9), edge);
    canvas.drawPath(
        _dashed(Board.roundedLoop(Board.vertices(17), Board.cornerRadius + 10), 14, 9), edge);

    _palace(canvas);
    for (final b in Board.branches) {
      _barracks(canvas, b);
    }
    _portalFrame(canvas);
  }

  static Path _dashed(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  static Paint _fill(Color c) => Paint()..color = c;
  static final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;

  static void _palace(Canvas canvas) {
    const x = Board.cx;
    const y = Board.cy;
    canvas.drawOval(Rect.fromCenter(center: const Offset(x, y + 60), width: 170, height: 20),
        _fill(const Color(0x33000000)));
    // 기단
    final base = Rect.fromLTWH(x - 74, y + 30, 148, 24);
    canvas.drawRect(base, _fill(const Color(0xFFBFB6A3)));
    canvas.drawRect(base, _line);
    // 몸채
    final body = Rect.fromLTWH(x - 56, y - 14, 112, 44);
    canvas.drawRect(body, _fill(const Color(0xFFE9DFC9)));
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(Rect.fromLTWH(x - 54 + i * 26, y - 14, 6, 44), _fill(const Color(0xFF9A3B2E)));
    }
    canvas.drawRect(Rect.fromLTWH(x - 12, y + 6, 24, 24), _fill(const Color(0xFF6B4A2A)));
    canvas.drawRect(body, _line);
    // 아래 지붕
    final roof1 = Path()
      ..moveTo(x - 80, y - 8)
      ..quadraticBezierTo(x - 66, y - 18, x - 58, y - 34)
      ..lineTo(x + 58, y - 34)
      ..quadraticBezierTo(x + 66, y - 18, x + 80, y - 8)
      ..quadraticBezierTo(x, y - 18, x - 80, y - 8)
      ..close();
    canvas.drawPath(roof1, _fill(const Color(0xFF3A4048)));
    canvas.drawPath(roof1, _line);
    // 위층
    canvas.drawRect(Rect.fromLTWH(x - 36, y - 52, 72, 18), _fill(const Color(0xFFE9DFC9)));
    canvas.drawRect(Rect.fromLTWH(x - 36, y - 52, 72, 18), _line);
    final roof2 = Path()
      ..moveTo(x - 58, y - 46)
      ..quadraticBezierTo(x - 46, y - 54, x - 40, y - 68)
      ..lineTo(x + 40, y - 68)
      ..quadraticBezierTo(x + 46, y - 54, x + 58, y - 46)
      ..quadraticBezierTo(x, y - 54, x - 58, y - 46)
      ..close();
    canvas.drawPath(roof2, _fill(const Color(0xFF3A4048)));
    canvas.drawPath(roof2, _line);
    canvas.drawLine(const Offset(x - 40, y - 68), const Offset(x + 40, y - 68),
        Paint()
          ..color = const Color(0xFFE3C77A)
          ..strokeWidth = 3);
  }

  static void _barracks(Canvas canvas, Branch b) {
    final x = b.x;
    const y = Board.cy;
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 6), width: 92, height: 14),
        _fill(const Color(0x33000000)));
    final tent = Path()
      ..moveTo(x - 42, y + 4)
      ..quadraticBezierTo(x - 22, y - 20, x, y - 40)
      ..quadraticBezierTo(x + 22, y - 20, x + 42, y + 4)
      ..close();
    canvas.drawPath(tent, _fill(b.color));
    final shade = Path()
      ..moveTo(x, y - 40)
      ..quadraticBezierTo(x + 22, y - 20, x + 42, y + 4)
      ..lineTo(x + 14, y + 4)
      ..close();
    canvas.drawPath(shade, _fill(const Color(0x33000000)));
    final door = Path()
      ..moveTo(x - 12, y + 4)
      ..lineTo(x, y - 18)
      ..lineTo(x + 12, y + 4)
      ..close();
    canvas.drawPath(door, _fill(_ink));
    canvas.drawPath(tent, _line);
    canvas.drawLine(Offset(x, y - 40), Offset(x, y - 56), _line);
    final flag = Path()
      ..moveTo(x, y - 56)
      ..lineTo(x + 16, y - 51)
      ..lineTo(x, y - 46)
      ..close();
    canvas.drawPath(flag, _fill(const Color(0xFFF2C14E)));

    final tp = TextPainter(
      text: TextSpan(
        text: b.name,
        style: TextStyle(
            fontFamily: 'Pretendard', fontSize: 17, fontWeight: FontWeight.w700, color: b.color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final chip = Rect.fromCenter(
        center: Offset(x, y + 24), width: tp.width + 16, height: tp.height + 2);
    canvas.drawRRect(RRect.fromRectAndRadius(chip, const Radius.circular(6)),
        _fill(const Color(0xFFFBF8F1)));
    tp.paint(canvas, Offset(x - tp.width / 2, y + 24 - tp.height / 2));
  }

  static void _portalFrame(Canvas canvas) {
    final c = Offset(Board.joinX, Board.portalY);
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, 26), width: 86, height: 16),
        _fill(const Color(0x33000000)));
    final ring = Rect.fromCenter(center: c, width: 78, height: 64);
    canvas.drawOval(ring, _fill(const Color(0xFF6B6259)));
    canvas.drawOval(ring, _line);
    canvas.drawOval(ring.deflate(9), _fill(const Color(0xFF2B1840)));
  }
}

/// 포탈 안쪽 소용돌이 (회전 애니메이션).
class PortalSwirl extends PositionComponent {
  PortalSwirl()
      : super(
            position: Vector2(Board.joinX, Board.portalY),
            size: Vector2(60, 46),
            anchor: Anchor.center,
            priority: 1);

  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(1, size.y / size.x);
    canvas.rotate(_t * 2.2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      p
        ..strokeWidth = 4 - i.toDouble()
        ..color = i.isEven ? const Color(0xFF8E5CC8) : const Color(0xFFC9A3F0);
      final r = 26.0 - i * 7;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), i * 2.1, 3.6, false, p);
    }
    canvas.restore();
  }
}
