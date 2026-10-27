import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'board.dart';
import 'mallang_game.dart';
import 'sheets.dart';

/// 움직이지 않는 맵(배경 + 장식)을 한 번만 합성해 이미지로 두고 매 프레임 그대로 찍는다.
/// 건물과 동굴은 움직이므로 따로 컴포넌트로 그린다.
class MapLayer extends PositionComponent with HasGameReference<MallangGame> {
  MapLayer() : super(size: Vector2(Board.width, Board.height), priority: 0);

  ui.Image? _image;

  @override
  Future<void> onLoad() async {
    // 배경과 장식 그림을 한꺼번에 받는다
    final kinds = {for (final d in game.map.decorations) d.kind}.toList();
    final r = await Future.wait([
      game.images.load('map/map-bg.png'),
      for (final k in kinds) Still.load(game.images, 'map/map-prop-$k.png'),
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
      Paint()..filterQuality = FilterQuality.medium,
    );
    final decos = [...game.map.decorations]..sort((a, b) => a.foot.dy.compareTo(b.foot.dy));
    for (final d in decos) {
      props[d.kind]!.draw(canvas, d.foot);
    }
    final picture = recorder.endRecording();
    _image = await picture.toImage((Board.width * artScale).toInt(), (Board.height * artScale).toInt());
    picture.dispose();
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
  SpawnCave() : super(priority: 1);

  late Sheet _sheet;
  double _t = 0;

  @override
  Future<void> onLoad() async {
    _sheet = await Sheet.load(game.images, 'map/map-spawn-cave.json');
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) => _sheet.draw(canvas, _sheet.frameAt(_t), game.map.cave);
}

/// 궁 (보급병이 나올 때 들썩임). 누르면 보급 설정 창.
class Palace extends PositionComponent with TapCallbacks, HasGameReference<MallangGame> {
  Palace() : super(priority: 2);

  late Still _still;
  late Sheet _enter;
  double _enterT = -1;

  void bounce() => _enterT = 0;

  @override
  bool containsLocalPoint(Vector2 point) => game.map.palace.rect.inflate(8).contains(point.toOffset());

  @override
  void onTapDown(TapDownEvent event) => game.openPalace();

  @override
  Future<void> onLoad() async {
    final r = await Future.wait([
      Still.load(game.images, 'map/map-bld-palace.png'),
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
    final foot = game.map.palace.foot;
    if (_enterT >= 0) {
      _enter.draw(canvas, _enter.frameAt(_enterT, loop: false), foot);
    } else {
      _still.draw(canvas, foot);
    }
  }
}
