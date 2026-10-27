import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'board.dart';
import 'mallang_game.dart';
import 'rules.dart';

const _ink = Color(0xFF2A211C);
const _gold = Color(0xFFF2C14E);
const _goldDark = Color(0xFFB8891E);

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

/// 몬스터를 잡으면 그 자리에서 엽전이 튀어 올랐다가 패널의 은냥 칸으로 날아간다.
class CoinFly extends PositionComponent with HasGameReference<MallangGame> {
  CoinFly(this.from, this.amount) : super(priority: 60);

  final Offset from;
  final int amount;
  double _t = 0;
  static const double _pop = 0.28;
  static const double _fly = 0.55;

  Offset get _target => Offset(Board.playWidth + Hud.coinCenter.dx, Hud.coinCenter.dy);

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= _pop + _fly) {
      game.hud.coinArrived(amount);
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

/// 오른쪽 반투명 패널 + 알림 글자.
class Hud extends PositionComponent with TapCallbacks, HasGameReference<MallangGame> {
  Hud()
      : super(
          position: Vector2(Board.playWidth, 0),
          size: Vector2(Board.width - Board.playWidth, Board.height),
          priority: 50,
        );

  static const _speedBtn = Rect.fromLTWH(12, 648, 132, 52);
  static const _silverBox = Rect.fromLTWH(8, 286, 140, 42);
  static const coinCenter = Offset(28, 307);
  static const _drawBtn = Rect.fromLTWH(10, 336, 136, 56);
  static Rect _upBtn(int g) => Rect.fromLTWH(10, 400.0 + g * 48, 136, 44);

  double _t = 0;
  double _shownSilver = 0;
  double _bump = 0; // 엽전이 도착할 때 은냥 칸이 톡 커짐
  int _recent = 0; // 방금 들어온 은냥 합계
  double _recentT = 0;
  final List<double> _press = List.filled(5, 0);
  final List<double> _flash = List.filled(5, 0);
  final List<bool> _flashOk = List.filled(5, true);
  double _drawPress = 0;

  void coinArrived(int amount) {
    _bump = 1;
    _recent += amount;
    _recentT = 1.4;
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y;

  @override
  void update(double dt) {
    final real = dt / (game.gameSpeed == 0 ? 1 : game.gameSpeed); // 화면 연출은 실제 시간 기준
    _t += real;
    final target = game.silver.toDouble();
    // 숫자가 촤르륵 올라가거나 내려감
    _shownSilver += (target - _shownSilver) * math.min(1, real * 10);
    if ((target - _shownSilver).abs() < 0.5) _shownSilver = target;
    if (_bump > 0) _bump = math.max(0, _bump - real * 5);
    if (_recentT > 0) {
      _recentT -= real;
      if (_recentT <= 0) _recent = 0;
    }
    if (_drawPress > 0) _drawPress = math.max(0, _drawPress - real * 6);
    for (var i = 0; i < 5; i++) {
      if (_press[i] > 0) _press[i] = math.max(0, _press[i] - real * 6);
      if (_flash[i] > 0) _flash[i] = math.max(0, _flash[i] - real * 1.4);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition.toOffset();
    if (_speedBtn.contains(p)) game.toggleSpeed();
    if (_drawBtn.contains(p)) {
      if (game.draw()) _drawPress = 1;
      return;
    }
    for (var g = 0; g < Rules.upgradeNames.length; g++) {
      if (!_upBtn(g).contains(p)) continue;
      if (!game.canUpgrade(g)) return; // 비활성: 아무 일도 안 함
      _press[g] = 1;
      final ok = game.tryUpgrade(g);
      if (ok != null) {
        _flash[g] = 1;
        _flashOk[g] = ok;
      }
    }
  }

  TextPainter _tp(String s, {double size = 16, Color color = _ink, bool bold = false}) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _text(Canvas c, String s, Offset at,
      {double size = 16, Color color = _ink, bool bold = false, bool center = false, bool right = false}) {
    final tp = _tp(s, size: size, color: color, bold: bold);
    tp.paint(c, center ? at - Offset(tp.width / 2, 0) : (right ? at - Offset(tp.width, 0) : at));
  }

  void _bar(Canvas c, double y, double ratio, Color color) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(12, y, 132, 10), const Radius.circular(5));
    c.drawRRect(r, Paint()..color = const Color(0x332A211C));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(12, y, 132 * ratio.clamp(0.0, 1.0), 10), const Radius.circular(5)),
        Paint()..color = color);
  }

  void _drawSilver(Canvas canvas) {
    final box = RRect.fromRectAndRadius(_silverBox, const Radius.circular(21));
    canvas.drawRRect(box.shift(const Offset(0, 2)), Paint()..color = const Color(0x33000000));
    canvas.drawRRect(
        box,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A3A2C), Color(0xFF2E241C)],
          ).createShader(_silverBox));
    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _goldDark);
    final s = 1 + 0.25 * math.sin(_bump * math.pi);
    canvas.save();
    canvas.translate(coinCenter.dx, coinCenter.dy);
    canvas.scale(s);
    drawYeopjeon(canvas, Offset.zero, 13);
    canvas.restore();
    final n = _tp('${_shownSilver.round()}', size: 22, bold: true, color: const Color(0xFFFBF8F1));
    n.paint(canvas, Offset(_silverBox.right - 30 - n.width, _silverBox.center.dy - n.height / 2));
    _text(canvas, '냥', Offset(_silverBox.right - 12, _silverBox.center.dy - 9), size: 14,
        color: const Color(0xFFE3C77A), right: true);
    if (_recent > 0) {
      final a = (_recentT / 1.4).clamp(0.0, 1.0);
      _text(canvas, '+$_recent', Offset(_silverBox.right - 8, _silverBox.top - 18 - (1 - a) * 6),
          size: 14, bold: true, color: const Color(0xFFE7EBF0).withValues(alpha: a), right: true);
    }
  }

  void _drawUpgrade(Canvas canvas, int gi) {
    final g = game;
    final base = _upBtn(gi);
    final locked = gi >= 2;
    final lv = g.upgradeLv[gi];
    final max = Rules.upgradeMax[gi];
    final maxed = lv >= max;
    final cost = g.upgradeCost(gi);
    final afford = g.canUpgrade(gi);
    final press = math.sin(_press[gi] * math.pi) * 0.04;

    canvas.save();
    canvas.translate(base.center.dx, base.center.dy);
    canvas.scale(1 - press);
    canvas.translate(-base.center.dx, -base.center.dy);

    final rr = RRect.fromRectAndRadius(base, const Radius.circular(12));
    // 그림자 (누를 수 있을 때만 떠 있는 느낌)
    if (afford) {
      canvas.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = const Color(0x40000000));
    }
    final colors = locked
        ? const [Color(0x55FFFFFF), Color(0x40FFFFFF)]
        : afford
            ? const [Color(0xFFFFF6DC), Color(0xFFF7DB8C)]
            : maxed
                ? const [Color(0xFFEAF4E4), Color(0xFFD3E6C8)]
                : const [Color(0xFFEDEAE3), Color(0xFFDCD7CD)];
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)
              .createShader(base));
    // 누를 수 있으면 금색 테두리가 은은하게 빛남
    final glow = afford ? 0.6 + 0.4 * math.sin(_t * 3) : 0.0;
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = afford ? 2.5 : 1.5
          ..color = afford
              ? Color.lerp(_goldDark, _gold, glow)!
              : (maxed ? const Color(0xFF6E8A5A) : const Color(0x332A211C)));

    final fg = locked
        ? const Color(0x662A211C)
        : afford
            ? _ink
            : const Color(0x992A211C);
    _text(canvas, Rules.upgradeNames[gi], Offset(base.left + 10, base.top + 3), size: 13, bold: true, color: fg);
    _text(canvas, locked ? '' : 'Lv $lv', Offset(base.right - 10, base.top + 3), size: 13, bold: true, color: fg, right: true);

    // 레벨 진행 막대
    if (!locked) {
      final bar = Rect.fromLTWH(base.left + 10, base.top + 21, base.width - 20, 4);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(2)), Paint()..color = const Color(0x262A211C));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bar.left, bar.top, bar.width * lv / max, bar.height), const Radius.circular(2)),
          Paint()..color = maxed ? const Color(0xFF6E8A5A) : _goldDark);
    }

    // 아랫줄: 비용 · 확률 / 준비 중 / 최대
    final y = base.top + 27;
    if (locked) {
      _drawLock(canvas, Offset(base.left + 16, y + 8));
      _text(canvas, '준비 중', Offset(base.left + 28, y), size: 13, color: fg);
    } else if (maxed) {
      _text(canvas, '최대 강화', Offset(base.left + 10, y), size: 13, bold: true, color: const Color(0xFF4F6B3E));
    } else {
      drawYeopjeon(canvas, Offset(base.left + 17, y + 8), 6.5, alpha: afford ? 1 : 0.55);
      _text(canvas, '$cost', Offset(base.left + 27, y), size: 13, bold: true,
          color: afford ? const Color(0xFF6B4A10) : const Color(0xFFB0473F));
      _text(canvas, '성공 50%', Offset(base.right - 10, y), size: 12, color: fg, right: true);
    }

    // 결과 번쩍임 + 글자
    final f = _flash[gi];
    if (f > 0) {
      final col = _flashOk[gi] ? const Color(0xFF4CAF50) : const Color(0xFFE0483E);
      canvas.drawRRect(rr, Paint()..color = col.withValues(alpha: 0.35 * f));
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = col.withValues(alpha: f));
    }
    canvas.restore();
    if (f > 0) {
      final ok = _flashOk[gi];
      _text(canvas, ok ? '성공!' : '실패', Offset(base.center.dx, base.top - 4 - (1 - f) * 18),
          size: 16, bold: true, center: true,
          color: (ok ? const Color(0xFF2E7D32) : const Color(0xFFC0392B)).withValues(alpha: math.min(1, f * 1.5)));
    }
  }

  /// 뽑기 버튼: 무료권이 있으면 빨간 '무료 n' 배지 + 금빛 테두리, 없으면 비용, 못 뽑으면 회색.
  void _drawDrawButton(Canvas canvas) {
    final g = game;
    final base = _drawBtn;
    final free = g.freeDraws;
    final can = g.canDraw;
    final press = math.sin(_drawPress * math.pi) * 0.05;
    canvas.save();
    canvas.translate(base.center.dx, base.center.dy);
    canvas.scale(1 - press);
    canvas.translate(-base.center.dx, -base.center.dy);
    final rr = RRect.fromRectAndRadius(base, const Radius.circular(14));
    if (can) canvas.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = const Color(0x40000000));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: can
                ? const [Color(0xFFFFE08A), Color(0xFFF2C14E)]
                : const [Color(0xFFEDEAE3), Color(0xFFDCD7CD)],
          ).createShader(base));
    final glow = free > 0 ? 0.5 + 0.5 * math.sin(_t * 4) : 0.0;
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = free > 0 ? 3 : 2
          ..color = free > 0 ? Color.lerp(_goldDark, const Color(0xFFFFF4D6), glow)! : (can ? _goldDark : const Color(0x332A211C)));
    final fg = can ? _ink : const Color(0x992A211C);
    _text(canvas, '뽑기', Offset(base.left + 14, base.top + 8), size: 20, bold: true, color: fg);
    if (free > 0) {
      _text(canvas, '무료', Offset(base.left + 14, base.top + 33), size: 13, bold: true, color: const Color(0xFF8C2F2B));
    } else if (can) {
      drawYeopjeon(canvas, Offset(base.left + 21, base.top + 41), 6.5);
      _text(canvas, '${Rules.drawCost}', Offset(base.left + 31, base.top + 33), size: 13, bold: true,
          color: const Color(0xFF6B4A10));
    } else {
      _text(canvas, '은냥 부족', Offset(base.left + 14, base.top + 33), size: 13, color: fg);
    }
    _text(canvas, '군졸 1명', Offset(base.right - 12, base.top + 34), size: 12, color: fg, right: true);
    canvas.restore();
    if (free > 0) {
      final tp = _tp('무료 $free', size: 13, bold: true, color: const Color(0xFFFFFFFF));
      final r = Rect.fromLTWH(base.right - tp.width - 18, base.top - 9, tp.width + 14, 22);
      final rb = RRect.fromRectAndRadius(r, const Radius.circular(11));
      canvas.drawRRect(rb, Paint()..color = const Color(0xFFE0483E));
      canvas.drawRRect(
          rb,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _ink);
      tp.paint(canvas, Offset(r.left + 7, r.center.dy - tp.height / 2));
    }
  }

  void _drawLock(Canvas c, Offset p) {
    final paint = Paint()..color = const Color(0x802A211C);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p.translate(0, 2), width: 10, height: 8), const Radius.circular(2)), paint);
    c.drawArc(Rect.fromCenter(center: p.translate(0, -2), width: 7, height: 8), math.pi, math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0x802A211C));
  }

  @override
  void render(Canvas canvas) {
    final g = game;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = const Color(0xA6FBF8F1));
    canvas.drawLine(const Offset(0, 0), Offset(0, size.y),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0x402A211C));

    final left = (Rules.roundSeconds - g.roundTime).clamp(0, Rules.roundSeconds);
    if (g.preparing) {
      _text(canvas, '준비 라운드', const Offset(12, 14), size: 14, bold: true, color: const Color(0xFF2E5E8C));
      _text(canvas, '준비', const Offset(12, 32), size: 30, bold: true, color: const Color(0xFF2E5E8C));
      _text(canvas, '전투 시작까지 ${g.prepLeft.toStringAsFixed(1)}초', const Offset(12, 74), size: 13);
      _bar(canvas, 94, g.prepLeft / Rules.prepSeconds, const Color(0xFF8EC7F0));
    } else {
      _text(canvas, '라운드', const Offset(12, 14), size: 14);
      _text(canvas, '${g.round} / ${Rules.lastRound}', const Offset(12, 32), size: 30, bold: true);
      _text(canvas, '다음 라운드 ${left.toStringAsFixed(1)}초', const Offset(12, 74), size: 13);
      _bar(canvas, 94, g.roundTime / Rules.roundSeconds, const Color(0xFF2E5E8C));
    }

    final n = g.monsters.length;
    final danger = n >= Rules.loseCount * 0.8;
    _text(canvas, '몬스터', const Offset(12, 124), size: 14);
    _text(canvas, '$n / ${Rules.loseCount}', const Offset(12, 142),
        size: 26, bold: true, color: danger ? const Color(0xFFC0392B) : _ink);
    _bar(canvas, 178, n / Rules.loseCount, danger ? const Color(0xFFC0392B) : const Color(0xFF8A6E4B));

    final boss = g.boss;
    if (boss != null && !boss.dead) {
      _text(canvas, '보스', const Offset(12, 202), size: 14, color: const Color(0xFF8C2F2B), bold: true);
      _text(canvas, '${(boss.hp).ceil()} / ${boss.maxHp.toInt()}', const Offset(12, 220), size: 15, bold: true);
      _bar(canvas, 242, boss.hp / boss.maxHp, const Color(0xFFE0483E));
      _text(canvas, '${left.toStringAsFixed(1)}초 안에 처치', const Offset(12, 257),
          size: 13, color: const Color(0xFF8C2F2B));
    }

    _drawSilver(canvas);
    _drawDrawButton(canvas);
    for (var gi = 0; gi < Rules.upgradeNames.length; gi++) {
      _drawUpgrade(canvas, gi);
    }

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

    _text(canvas, '빌드 ${const String.fromEnvironment('BUILD', defaultValue: 'dev')}', const Offset(12, 703),
        size: 11, color: const Color(0x992A211C));

    final t = g.toastText;
    if (t != null) {
      final tp = _tp(t, size: 18, bold: true, color: const Color(0xFFFFFFFF));
      final c = Offset(Board.playWidth / 2 - position.x, 668);
      final r = Rect.fromCenter(center: c, width: tp.width + 32, height: tp.height + 14);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), Paint()..color = const Color(0xE62A211C));
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }
}
