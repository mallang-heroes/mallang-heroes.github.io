import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/board.dart';
import '../game/sheets.dart';

import '../game/mallang_game.dart';
import '../game/rules.dart';
import '../game/units.dart';

const _ink = Color(0xFF2A211C);
const _paper = Color(0xF2FBF8F1);

/// 보드 좌표(1560×720)로 배치하고 게임 화면과 같은 비율로 맞춘다.
class BoardSpace extends StatelessWidget {
  const BoardSpace({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: Board.width,
          height: Board.height,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }
}

/// 막사 창: 승진 · 장수 소환 · 판매 (기존 테스트판 디자인).
class BarracksDialog extends StatelessWidget {
  const BarracksDialog({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: game.closeBarracks,
            child: const ColoredBox(color: Color(0x26141812)),
          ),
        ),
        BoardSpace(children: [
          Positioned(
            left: 352,
            top: 120,
            width: 700,
            child: ValueListenableBuilder<int>(
              valueListenable: game.changes,
              builder: (context, _, __) {
                final br = game.selectedBranch;
                if (br == null) return const SizedBox.shrink();
                return _BarracksPanel(game: game, branch: br);
              },
            ),
          ),
        ]),
      ],
    );
  }
}

class _BarracksPanel extends StatelessWidget {
  const _BarracksPanel({required this.game, required this.branch});
  final MallangGame game;
  final String branch;

  @override
  Widget build(BuildContext context) {
    final b = game.barracks[branch]!;
    final color = branchColor(branch);
    final k = b.counts;
    final have = k.where((n) => n > 0).length;
    final sheets = game.tierIdle[branch];
    const disabled = Color(0xFF9AA08A);
    const dark = Color(0xFF2A2F35);

    final actions = [
      ('정병 승진 ${k[0].clamp(0, 3)} / 3', k[0] >= 3 ? dark : disabled, () => game.promote(branch, 0)),
      ('군관 승진 ${k[1].clamp(0, 3)} / 3', k[1] >= 3 ? dark : disabled, () => game.promote(branch, 1)),
      ('장수 소환 $have / 3', have == 3 ? color : disabled, () => game.summonGeneral(branch)),
    ];

    return Material(
      color: const Color(0xEBFBF8F1),
      elevation: 12,
      shadowColor: const Color(0x47000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('$branch 막사',
                    style: TextStyle(
                        fontFamily: 'GowunBatang', fontSize: 28, fontWeight: FontWeight.w700, color: color)),
                const Spacer(),
                _RoundClose(onTap: game.closeBarracks),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var t = 0; t < 3; t++) ...[
                  if (t > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _TierCard(
                      sheet: sheets?[t],
                      color: color,
                      title: '$branch ${Rules.tierNames[t]}',
                      count: k[t],
                      actionLabel: actions[t].$1,
                      actionColor: actions[t].$2,
                      onAction: actions[t].$3,
                      sellPrice: Rules.sellPrice[t],
                      onSell: () => game.sell(branch, t),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '같은 병과 3명이 모이면 다음 등급으로 승진 (결과 병과는 랜덤) · 장수는 같은 병과 군관 · 정병 · 군졸 1명씩 · 판매하면 은냥 획득',
              style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF3E4248)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundClose extends StatelessWidget {
  const _RoundClose({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '닫기',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9C3B3)),
          ),
          child: const Icon(Icons.close, size: 24, color: Color(0xFF2A2F35)),
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.sheet,
    required this.color,
    required this.title,
    required this.count,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
    required this.sellPrice,
    required this.onSell,
  });

  final Sheet? sheet;
  final Color color;
  final String title;
  final int count;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
  final int sellPrice;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDD6C5), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: SheetView(sheet: sheet, color: color, width: 88, height: 102, dim: count == 0)),
              const SizedBox(height: 4),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
              Text('× $count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 4),
              SizedBox(
                height: 56,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SizedBox(
            height: 44,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: const Color(0xFFFFF4D6),
                foregroundColor: const Color(0xFF7A5A10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFB8891E), width: 2),
                ),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              onPressed: count > 0 ? onSell : null,
              child: Text('판매 +$sellPrice'),
            ),
          ),
        ),
      ],
    );
  }
}

/// 스프라이트 시트를 Flutter 화면에서 반복 재생 (막사 창 등).
class SheetView extends StatefulWidget {
  const SheetView({
    super.key,
    required this.sheet,
    required this.color,
    required this.width,
    required this.height,
    this.dim = false,
  });

  final Sheet? sheet;
  final Color color;
  final double width;
  final double height;
  final bool dim;

  @override
  State<SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends State<SheetView> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 600))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _SheetPainter(widget.sheet, widget.color, widget.dim, _clock),
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(this.sheet, this.color, this.dim, this.clock) : super(repaint: clock);

  final Sheet? sheet;
  final Color color;
  final bool dim;
  final AnimationController clock;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 600;
    if (dim) canvas.saveLayer(null, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.45));
    final s = sheet;
    if (s == null) {
      // 그림이 아직 없는 병과: 통통 튀는 임시 슬라임
      final bob = math.sin(t * 4) * 2;
      final body = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.62 + bob), width: size.width * 0.7, height: size.height * 0.55);
      canvas.drawOval(body, Paint()..color = color);
      canvas.drawOval(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _ink);
    } else {
      final i = s.frameAt(t);
      final f = s.frames[i];
      final fw = f.src.width / artScale;
      final fh = f.src.height / artScale;
      final k = math.min(size.width / fw, size.height / fh);
      canvas.save();
      canvas.translate(size.width / 2 + (f.anchor.dx - 0.5) * fw * k, size.height - (1 - f.anchor.dy) * fh * k);
      canvas.scale(k);
      s.draw(canvas, i, Offset.zero);
      canvas.restore();
    }
    if (dim) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SheetPainter old) =>
      old.sheet != sheet || old.dim != dim || old.color != color;
}

/// 승리 · 패배 창.
class ResultDialog extends StatelessWidget {
  const ResultDialog({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    final won = game.phase == Phase.won;
    return ColoredBox(
      color: const Color(0x66000000),
      child: Center(
        child: Material(
          color: _paper,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(won ? '승리!' : '성이 함락됐어요',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: won ? const Color(0xFF3F6B3A) : const Color(0xFF8C2F2B))),
                const SizedBox(height: 8),
                Text(game.endReason, style: const TextStyle(fontSize: 17, color: _ink)),
                const SizedBox(height: 4),
                Text('${game.round}라운드 · 처치 ${game.kills}',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF5C6066))),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                  onPressed: game.restart,
                  child: const Text('다시 하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 세로 화면 안내.
class RotateHint extends StatelessWidget {
  const RotateHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xF23E4A2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screen_rotation, size: 64, color: Colors.white),
            SizedBox(height: 16),
            Text('화면을 가로로 돌려 주세요',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
