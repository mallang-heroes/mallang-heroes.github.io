import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'board.dart';
import 'mallang_game.dart';
import 'sheets.dart';

/// 움직이지 않는 맵(풀밭 + 길 + 배치 칸 + 장식)을 한 번만 합성해 이미지로 두고 매 프레임 그대로 찍는다.
/// 궁과 동굴은 움직이므로 따로 컴포넌트로 그린다.
class MapLayer extends PositionComponent with HasGameReference<MallangGame> {
  MapLayer() : super(size: Vector2(Board.width, Board.height), priority: 0);

  ui.Image? _image;

  @override
  Future<void> onLoad() async {
    final kinds = {for (final d in MapData.decorations) d.kind}.toList();
    final r = await Future.wait([
      game.images.load('map/map-grass.webp'),
      for (final k in kinds) Still.load(game.images, 'map/map-prop-$k.webp'),
    ]);
    final bg = r[0] as ui.Image;
    final props = <String, Still>{for (var i = 0; i < kinds.length; i++) kinds[i]: r[i + 1] as Still};

    // 화면 배율과 상관없이 선명하도록 @2x로 합성한다.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(artScale);
    canvas.drawImageRect(
      bg,
      Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
      const Rect.fromLTWH(0, 0, Board.width, Board.height),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = _desaturate,
    );
    _drawRoad(canvas);
    _drawTiles(canvas);
    final decos = [...MapData.decorations]..sort((a, b) => a.foot.dy.compareTo(b.foot.dy));
    for (final d in decos) {
      props[d.kind]!.draw(canvas, d.foot);
    }
    final picture = recorder.endRecording();
    _image = await picture.toImage((Board.width * artScale).toInt(), (Board.height * artScale).toInt());
    picture.dispose();
  }

  /// 풀밭 채도를 살짝 낮춰 유닛·몬스터가 돋보이게 한다.
  static const ColorFilter _desaturate = ColorFilter.matrix(<double>[
    0.88, 0.10, 0.02, 0, 4, //
    0.05, 0.92, 0.03, 0, 4, //
    0.05, 0.10, 0.85, 0, 4, //
    0, 0, 0, 1, 0,
  ]);

  void _drawRoad(Canvas canvas) {
    final path = Path()..moveTo(MapData.path.first.dx + 40, MapData.path.first.dy);
    for (final p in MapData.path) {
      path.lineTo(p.dx, p.dy);
    }
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.butt
      ..color = c;
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, stroke(const Color(0x1F000000), MapData.roadWidth + 3));
    canvas.restore();
    canvas.drawPath(path, stroke(const Color(0xFF7A6446), MapData.roadWidth));
    canvas.drawPath(path, stroke(const Color(0xFFC9AD7E), MapData.roadWidth - 10));
    canvas.drawPath(path, stroke(const Color(0xB3DCC59A), 20));
    // 바퀴 자국 점선
    final dash = stroke(const Color(0xB3A8895E), 2);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 27) {
        canvas.drawPath(m.extractPath(d, d + 10), dash);
      }
    }
  }

  void _drawTiles(Canvas canvas) {
    final fill = Paint()..color = const Color(0x2EFFF6C8);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x80FFF0BE);
    for (final c in MapData.tiles) {
      final r = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: MapData.tile, height: MapData.tile), const Radius.circular(15));
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r.deflate(1.5), line);
    }
  }

  @override
  void render(Canvas canvas) {
    final img = _image;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      const Rect.fromLTWH(0, 0, Board.width, Board.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

/// 몬스터 출현 동굴 (보라 기운 4프레임 반복).
class SpawnCave extends PositionComponent with HasGameReference<MallangGame> {
  SpawnCave() : super(priority: 7);

  late Sheet _sheet;
  double _t = 0;

  @override
  Future<void> onLoad() async {
    _sheet = await Sheet.load(game.images, 'map/map-spawn-cave.json');
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) => _sheet.draw(canvas, _sheet.frameAt(_t), MapData.cave);
}

/// 궁 (몬스터가 닿으면 들썩임). 궁 체력은 위쪽 정보줄에 보인다.
class Palace extends PositionComponent with HasGameReference<MallangGame> {
  Palace() : super(priority: 2);

  late Still _still;
  late Sheet _enter;
  double _enterT = -1;

  /// 몬스터가 닿거나 유닛이 나올 때 들썩인다.
  void bounce() => _enterT = 0;

  @override
  Future<void> onLoad() async {
    final r = await Future.wait([
      Still.load(game.images, 'map/map-bld-palace.webp'),
      Sheet.load(game.images, 'map/map-bld-palace-enter.json'),
    ]);
    _still = r[0] as Still;
    _enter = r[1] as Sheet;
  }

  @override
  void update(double dt) {
    if (_enterT >= 0) {
      _enterT += dt;
      if (_enterT > _enter.duration) _enterT = -1;
    }
  }

  @override
  void render(Canvas canvas) {
    const foot = MapData.palace;
    if (_enterT >= 0) {
      _enter.draw(canvas, _enter.frameAt(_enterT, loop: false), foot);
    } else {
      _still.draw(canvas, foot);
    }
  }
}
