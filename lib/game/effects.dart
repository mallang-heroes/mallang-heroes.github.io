import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

final _rng = math.Random();

/// 맞은 자리 불꽃: 짧은 빛살 + 퍼지는 고리 + 튀는 불티. 치명타는 크고 금빛.
class HitSpark extends PositionComponent {
  HitSpark(Vector2 at, {this.crit = false, this.big = false}) : super(position: at, priority: 16) {
    final n = crit ? 10 : 7;
    for (var i = 0; i < n; i++) {
      _rays.add(_Ray(i / n * math.pi * 2 + _rng.nextDouble() * 0.4, 0.7 + _rng.nextDouble() * 0.5));
    }
    for (var i = 0; i < (crit ? 7 : 4); i++) {
      final a = -math.pi * (0.1 + _rng.nextDouble() * 0.8);
      final s = 60 + _rng.nextDouble() * 70;
      _bits.add(_Bit(Offset(math.cos(a) * s, math.sin(a) * s)));
    }
  }

  final bool crit;
  final bool big;
  final List<_Ray> _rays = [];
  final List<_Bit> _bits = [];
  double _t = 0;
  static const double _flash = 0.2;
  static const double _life = 0.36;

  @override
  void update(double dt) {
    _t += dt;
    for (final b in _bits) {
      b.p += b.v * dt;
      b.v += Offset(0, 420 * dt);
    }
    if (_t > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (big ? 1.6 : 1.0) * (crit ? 1.35 : 1.0);
    if (_t < _flash) {
      final p = _t / _flash;
      final r = 13 * k;
      canvas.drawCircle(Offset.zero, r * 0.38 * (1 - p * 0.6),
          Paint()..color = const Color(0xFFFFF7D6).withValues(alpha: 1 - p));
      final ray = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (crit ? 2.6 : 2.0) * (1 - p) + 0.4
        ..color = (crit ? const Color(0xFFFFC93C) : const Color(0xFFFFE48A)).withValues(alpha: 1 - p);
      for (final s in _rays) {
        final r0 = r * (0.2 + 0.5 * p);
        final r1 = r * (0.55 + 0.7 * p) * s.len;
        final d = Offset(math.cos(s.angle), math.sin(s.angle));
        canvas.drawLine(d * r0, d * r1, ray);
      }
      canvas.drawCircle(
          Offset.zero,
          r * (0.4 + 0.8 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * (1 - p) + 0.2
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * (1 - p)));
    }
    final a = (1 - _t / _life).clamp(0.0, 1.0);
    final bit = Paint()..color = const Color(0xFFFFECA0).withValues(alpha: a);
    for (final b in _bits) {
      canvas.drawCircle(b.p, 1.6 * k * a + 0.4, bit);
    }
  }
}

class _Ray {
  _Ray(this.angle, this.len);
  final double angle;
  final double len;
}

class _Bit {
  _Bit(this.v);
  Offset p = Offset.zero;
  Offset v;
}

/// 맞을 때 튀어 오르는 피해 숫자. 화면이 숫자로 덮이지 않게 한꺼번에 [maxLive]개까지만 둔다.
class DamageText extends PositionComponent {
  DamageText(this.value, Vector2 at, {this.crit = false})
      : super(position: at + Vector2((_rng.nextDouble() - 0.5) * 12, 0), priority: 31) {
    _live.add(this);
    while (_live.length > maxLive) {
      _live.removeAt(0).removeFromParent();
    }
  }

  static final List<DamageText> _live = [];
  static const int maxLive = 40;
  static const double _life = 0.75;

  final int value;
  final bool crit;
  double _t = 0;
  TextPainter? _fill;
  TextPainter? _stroke;

  @override
  void onRemove() {
    _live.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _life) removeFromParent();
  }

  TextPainter _paint(TextStyle style) =>
      TextPainter(text: TextSpan(text: '$value', style: style), textDirection: TextDirection.ltr)..layout();

  @override
  void render(Canvas canvas) {
    final size = crit ? 22.0 : 16.0;
    final base = TextStyle(fontFamily: 'Pretendard', fontSize: size, fontWeight: FontWeight.w700, height: 1);
    _stroke ??= _paint(base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.24
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF3A2210)));
    _fill ??= _paint(base.copyWith(color: crit ? const Color(0xFFFFD23F) : const Color(0xFFFFFFFF)));
    final pop = _t < 0.12 ? 1 + 0.5 * math.sin(_t / 0.12 * math.pi) : 1.0;
    final rise = 22 * (1 - math.exp(-_t * 6));
    final a = _t < 0.5 ? 1.0 : (1 - (_t - 0.5) / (_life - 0.5)).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(0, -rise);
    canvas.scale(pop);
    if (a < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, a));
    final o = Offset(-_fill!.width / 2, -_fill!.height);
    _stroke!.paint(canvas, o);
    _fill!.paint(canvas, o);
    if (a < 1) canvas.restore();
    canvas.restore();
  }
}

/// 근접 공격의 칼 궤적. [thrust]면 찌르기(곧은 줄), 아니면 위에서 앞·아래로 휘두르는 호.
class SlashTrail extends PositionComponent {
  SlashTrail(Vector2 from, Vector2 target, {this.thrust = false})
      : _to = (target - from).toOffset(),
        super(position: from, priority: 15);

  final bool thrust;
  final Offset _to; // from 기준 대상 위치
  double _t = 0;
  static const double _swing = 0.07;
  static const double _life = 0.24;

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = math.min(1.0, _t / _swing);
    final fade = (1 - math.max(0.0, (_t - 0.08) / (_life - 0.08))).clamp(0.0, 1.0);
    if (fade <= 0) return;
    const n = 18;
    final pts = <Offset>[];
    if (thrust) {
      for (var i = 0; i <= n; i++) {
        pts.add(_to * (i / n * p));
      }
    } else {
      final facing = _to.dx < 0 ? -1.0 : 1.0;
      final dist = _to.distance;
      final r = dist.clamp(36.0, 64.0) * 0.85;
      final aim = math.atan2(_to.dy, _to.dx.abs());
      final a1 = aim + 0.5;
      final a0 = a1 - 2.2;
      for (var i = 0; i <= n; i++) {
        final a = a0 + (a1 - a0) * (i / n * p);
        pts.add(Offset(facing * r * math.cos(a), r * math.sin(a)));
      }
    }
    final glow = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final core = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < pts.length - 1; i++) {
      final w = math.pow((i + 1) / (pts.length - 1), 1.6).toDouble();
      glow
        ..strokeWidth = (thrust ? 1.5 + 5 * w : 2 + 8 * w)
        ..color = const Color(0xFF96CDFF).withValues(alpha: 0.5 * fade * w);
      core
        ..strokeWidth = (thrust ? 0.6 + 2 * w : 0.8 + 3 * w)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: fade * math.min(1.0, w * 1.4));
      canvas.drawLine(pts[i], pts[i + 1], glow);
      canvas.drawLine(pts[i], pts[i + 1], core);
    }
  }
}

/// 몬스터 발 먼지 한 번 (몬스터가 지나간 자리에 남는다).
class DustPuff {
  DustPuff(this.at, this.back, this.scale);
  final Offset at; // 보드 좌표 (발 디딘 곳)
  final Offset back; // 먼지가 퍼지는 방향 (걷는 반대쪽)
  final double scale;
  double t = 0;
  static const double life = 0.45;

  /// [toLocal]: 보드 좌표에 더하면 그리는 캔버스 좌표가 되는 값.
  void draw(Canvas canvas, Offset toLocal) {
    final p = (t / life).clamp(0.0, 1.0);
    final paint = Paint()..color = const Color(0xFFECDEBE).withValues(alpha: 0.4 * (1 - p));
    for (var i = 0; i < 3; i++) {
      final c = at + toLocal + back * ((2 + i * 3) * p * 2 + i * 1.5) + Offset(0, -1.5 * p - i * 0.4);
      canvas.drawCircle(c, (1.4 + i * 0.5 + 2.2 * p) * scale, paint);
    }
  }
}
