import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 그림 파일은 모두 @2x. 보드 좌표로 그릴 때 1/2로 줄인다.
const double artScale = 2;
final Paint _artPaint = Paint()..filterQuality = FilterQuality.medium;

/// 한 장짜리 그림: 바닥 가운데(foot)에 맞춰 그린다.
class Still {
  Still(this.image);
  final ui.Image image;

  double get w => image.width / artScale;
  double get h => image.height / artScale;

  static Future<Still> load(Images images, String path) async => Still(await images.load(path));

  void draw(Canvas canvas, Offset foot, {bool flip = false}) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(foot.dx - w / 2, foot.dy - h, w, h);
    _drawFlipped(canvas, image, src, dst, foot.dx, flip);
  }
}

/// 스프라이트 시트 + JSON (TexturePacker Hash 호환, anchor·events 포함).
class Sheet {
  Sheet(this.image, this.frames, this.fps);

  final ui.Image image;
  final List<SheetFrame> frames;
  final double fps;

  int get length => frames.length;
  double get duration => frames.fold(0.0, (a, f) => a + f.seconds);

  /// [jsonPath]는 assets/images/ 아래 경로 (예: map/map-spawn-cave.json).
  static Future<Sheet> load(Images images, String jsonPath) async {
    final j = jsonDecode(await rootBundle.loadString('assets/images/$jsonPath')) as Map<String, dynamic>;
    final meta = j['meta'] as Map<String, dynamic>;
    final dir = jsonPath.contains('/') ? jsonPath.substring(0, jsonPath.lastIndexOf('/') + 1) : '';
    final image = await images.load('$dir${meta['image']}');
    final fps = (meta['fps'] as num?)?.toDouble() ?? 12;
    final all = j['frames'] as Map<String, dynamic>;
    final anims = j['animations'] as Map<String, dynamic>?;
    final names = anims != null && anims.isNotEmpty
        ? [for (final n in anims.values.first as List) n as String]
        : all.keys.toList();
    final frames = <SheetFrame>[];
    for (final n in names) {
      final f = all[n] as Map<String, dynamic>;
      final r = f['frame'] as Map<String, dynamic>;
      final a = f['anchor'] as Map<String, dynamic>?;
      final ev = f['events'] as Map<String, dynamic>?;
      Offset? point(String k) {
        final p = ev?[k] as Map<String, dynamic>?;
        return p == null ? null : Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());
      }

      frames.add(SheetFrame(
        src: Rect.fromLTWH((r['x'] as num).toDouble(), (r['y'] as num).toDouble(),
            (r['w'] as num).toDouble(), (r['h'] as num).toDouble()),
        anchor: Offset((a?['x'] as num?)?.toDouble() ?? 0.5, (a?['y'] as num?)?.toDouble() ?? 1),
        seconds: ((f['duration'] as num?)?.toDouble() ?? 1000 / fps) / 1000,
        hit: point('hit'),
        projectile: point('projectile'),
      ));
    }
    return Sheet(image, frames, fps);
  }

  /// [t]초 지점의 프레임 번호 ([loop]이면 반복, 아니면 마지막 프레임에서 멈춤).
  int frameAt(double t, {bool loop = true}) {
    final total = duration;
    if (loop) {
      t %= total;
    } else if (t >= total) {
      return frames.length - 1;
    }
    var acc = 0.0;
    for (var i = 0; i < frames.length; i++) {
      acc += frames[i].seconds;
      if (t < acc) return i;
    }
    return frames.length - 1;
  }

  void draw(Canvas canvas, int index, Offset foot, {bool flip = false}) {
    final f = frames[index];
    final w = f.src.width / artScale;
    final h = f.src.height / artScale;
    final dst = Rect.fromLTWH(foot.dx - f.anchor.dx * w, foot.dy - f.anchor.dy * h, w, h);
    _drawFlipped(canvas, image, f.src, dst, foot.dx, flip);
  }
}

class SheetFrame {
  const SheetFrame({
    required this.src,
    required this.anchor,
    required this.seconds,
    this.hit,
    this.projectile,
  });
  final Rect src;
  final Offset anchor; // 프레임 안 비율
  final double seconds;
  final Offset? hit; // @2x 프레임 픽셀
  final Offset? projectile;
}

void _drawFlipped(Canvas canvas, ui.Image image, Rect src, Rect dst, double axisX, bool flip) {
  if (!flip) {
    canvas.drawImageRect(image, src, dst, _artPaint);
    return;
  }
  canvas.save();
  canvas.translate(axisX, 0);
  canvas.scale(-1, 1);
  canvas.translate(-axisX, 0);
  canvas.drawImageRect(image, src, dst, _artPaint);
  canvas.restore();
}
