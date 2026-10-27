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
            top: 100,
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
    // 승진·장수 재료는 막사 + 맵 모두
    final all = [for (var t = 0; t < 3; t++) game.countOf(branch, t)];
    final have = [0, 1, 2].where((t) => all[t] > 0).length;
    final sheets = game.tierIdle[branch];
    const disabled = Color(0xFF9AA08A);
    const dark = Color(0xFF2A2F35);

    final actions = [
      ('정병 승진 ${all[0].clamp(0, 3)} / 3', all[0] >= 3 ? dark : disabled, () => game.promote(branch, 0)),
      ('군관 승진 ${all[1].clamp(0, 3)} / 3', all[1] >= 3 ? dark : disabled, () => game.promote(branch, 1)),
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
                      fieldCount: game.fieldCount(branch, t),
                      actionLabel: actions[t].$1,
                      actionColor: actions[t].$2,
                      onAction: actions[t].$3,
                      sellPrice: Rules.sellPrice[t],
                      onSell: () => game.sell(branch, t),
                      onTakeOut: () => game.takeOut(branch, t),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '막사 안 유닛은 공격하지 않아요 · 꺼내기로 집결지에 내보내기 · 승진·장수 재료는 막사와 맵의 유닛 모두 사용 (결과 병과는 랜덤) · 판매하면 은냥 획득',
              style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF3E4248)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundClose extends StatelessWidget {
  const _RoundClose({required this.onTap, this.size = 48});
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '닫기',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: size,
          height: size,
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
    required this.fieldCount,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
    required this.sellPrice,
    required this.onSell,
    required this.onTakeOut,
  });

  final Sheet? sheet;
  final Color color;
  final String title;
  final int count;
  final int fieldCount;
  final String? actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
  final int? sellPrice;
  final VoidCallback onSell;
  final VoidCallback onTakeOut;

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
              Text(fieldCount > 0 ? '맵에 $fieldCount명' : ' ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5C6066))),
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: actionLabel == null
                    ? null
                    : TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: count > 0 ? color : const Color(0xFFDDD6C5), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: count > 0 ? onTakeOut : null,
                  child: const Text('꺼내기'),
                ),
              ),
            ],
          ),
        ),
        if (sellPrice != null)
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

/// 위인 명단: 병과 → [명장 A, 명장 B, 천명].
const roster = {
  '창병': ['윤관', '척준경', '광개토대왕'],
  '궁병': ['이지란', '이성계', '주몽'],
  '포수': ['문익점', '장영실', '세종'],
  '기병': ['계백', '정년', '김유신'],
  '수군': ['장보고', '이억기', '이순신'],
  '술사': ['원효대사', '사명대사', '전우치'],
};

/// 유닛 상세 창 (테스트판 디자인): 그림 · 이름 · 정보 · 조합하기 · 집기 · 막사로 보내기.
class DetailDialog extends StatefulWidget {
  const DetailDialog({super.key, required this.game});
  final MallangGame game;

  @override
  State<DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends State<DetailDialog> {
  bool combo = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: game.closeDetail,
            child: const ColoredBox(color: Color(0x26141812)),
          ),
        ),
        BoardSpace(children: [
          Positioned(
            left: 422,
            top: 160,
            width: 560,
            height: 400,
            child: ValueListenableBuilder<int>(
              valueListenable: game.changes,
              builder: (context, _, __) {
                final u = game.detailUnit;
                if (u == null) return const SizedBox.shrink();
                return _detail(game, u);
              },
            ),
          ),
        ]),
      ],
    );
  }

  Widget _detail(MallangGame game, FieldUnit u) {
    final color = branchColor(u.branch);
    final st = Rules.stats[u.branch]!;
    final lv = game.upgradeLv[u.group];
    final isGeneral = u.tier >= 3;
    final atk = st.atk * Rules.damageScale * u.power;
    final effect = '공격력 ${atk.toStringAsFixed(0)} · 초당 ${(st.speed * game.speedMul(u.group)).toStringAsFixed(2)}회 · '
        '사거리 ${st.range == st.range.roundToDouble() ? st.range.toInt() : st.range} (반경 ${Rules.rangeRadius(u.branch).round()}px) · '
        '${st.aoe ? '광역: 사거리 안 맨 앞부터 3마리' : '단일: 사거리 안 맨 앞 1마리'} · 치명타 ${(st.crit * 100).round()}%';
    final sub = isGeneral
        ? '조합하기로 명장 · 천명으로 진화할 수 있어요 (명장은 다음 단계에서 추가)'
        : '같은 병과 ${Rules.tierNames[u.tier]} 3명이 모이면 막사 창에서 승진할 수 있어요';
    final sheet = game.fieldArt[u.branch]?[u.tier]?.idle;

    // 승진 / 장수 소환 (군졸·정병: 같은 병과 같은 등급 3명, 군관: 같은 병과 군관·정병·군졸)
    final int have;
    final String nextLabel;
    if (u.tier < 2) {
      have = game.countOf(u.branch, u.tier).clamp(0, 3);
      nextLabel = '${Rules.tierNames[u.tier + 1]} 승진 ($have/3)';
    } else {
      have = [0, 1, 2].where((t) => game.countOf(u.branch, t) > 0).length;
      nextLabel = '장수 소환 ($have/3)';
    }
    final canNext = have >= 3;

    Widget bigButton(String label, VoidCallback onTap, {required bool dark}) => Expanded(
          child: SizedBox(
            height: 60,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: dark ? const Color(0xFF2A2F35) : const Color(0xFFFFF4D6),
                foregroundColor: dark ? Colors.white : const Color(0xFF7A5A10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: dark ? const Color(0xFFF2C14E) : const Color(0xFFB8891E), width: 3),
                ),
                textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              onPressed: onTap,
              child: Text(label),
            ),
          ),
        );

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 190,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SheetView(sheet: sheet, color: Colors.white, width: 150, height: 174),
                  const SizedBox(height: 6),
                  Text(u.title,
                      style: const TextStyle(
                          fontFamily: 'GowunBatang', fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              _tag('${u.branch} · ${Rules.tierNames[u.tier]}', const Color(0xFFECE6D8), _ink),
                              _tag('공격', const Color(0xFFF4CCCC), _ink),
                              _tag('강화 $lv / ${Rules.upgradeMax[u.group]}', const Color(0xFF2A2F35), const Color(0xFFF2C14E)),
                            ]),
                          ),
                          _RoundClose(onTap: game.closeDetail),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(effect, style: const TextStyle(fontSize: 15, height: 1.5, color: _ink)),
                      const SizedBox(height: 8),
                      Text(sub, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF3E4248))),
                      const Spacer(),
                      Row(children: [
                        if (isGeneral) ...[
                          bigButton('⚒ 조합하기', () => setState(() => combo = true), dark: false),
                          const SizedBox(width: 10),
                        ] else ...[
                          Expanded(
                            child: SizedBox(
                              height: 60,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFF4D6),
                                  foregroundColor: const Color(0xFF7A5A10),
                                  disabledBackgroundColor: const Color(0xFFE6E2D8),
                                  disabledForegroundColor: const Color(0xFF9AA08A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: canNext ? const Color(0xFFB8891E) : const Color(0xFFC9C3B3), width: 3),
                                  ),
                                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                                onPressed: canNext ? () => game.promoteFrom(u) : null,
                                child: Text(nextLabel),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        bigButton('✋ 집기', game.pickUp, dark: true),
                      ]),
                      const SizedBox(height: 10),
                      if (!isGeneral)
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            onPressed: game.sendHome,
                            child: Text('막사로 보내기 (${u.branch} 막사)'),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 48,
                          child: Center(
                            child: Text('장수는 막사에 들어가지 않고 맵에서 싸워요',
                                style: TextStyle(fontSize: 14, color: Color(0xFF5C6066))),
                          ),
                        ),
                    ],
                  ),
                  if (combo && isGeneral) Positioned.fill(child: _comboPanel(game, u)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 15, color: fg)),
      );

  /// 조합하기 겹침 창: 명장 A · 명장 B · 천명 레시피와 재료 현황 (진화는 다음 단계에서).
  Widget _comboPanel(MallangGame game, FieldUnit u) {
    final order = Rules.branches;
    final i = order.indexOf(u.branch);
    final next = order[(i + 1) % order.length];
    final prev = order[(i + order.length - 1) % order.length];
    final names = roster[u.branch]!;
    final generals = game.countOf(u.branch, 3);
    final recipes = [
      ('${names[0]} (명장)', '${u.branch} 장수 2 + $next 군관 1', (generals >= 2 ? 2 : generals) + (game.countOf(next, 2) > 0 ? 1 : 0)),
      ('${names[1]} (명장)', '${u.branch} 장수 2 + $prev 군관 1', (generals >= 2 ? 2 : generals) + (game.countOf(prev, 2) > 0 ? 1 : 0)),
      ('${names[2]} (천명)', '${u.branch} 장수 1 + 천명 유물 (한 판 1명)', 1),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xDBFBF8F1),
        border: Border.all(color: const Color(0xFFB8891E), width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('조합하기', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF7A5A10))),
            const Spacer(),
            _RoundClose(onTap: () => setState(() => combo = false), size: 44),
          ]),
          const SizedBox(height: 6),
          for (final r in recipes) ...[
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDDD6C5), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(r.$1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
                    Text(r.$2, style: const TextStyle(fontSize: 14, color: Color(0xFF3E4248))),
                  ]),
                ),
                Text('${r.$3} / 3', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF5C6066))),
              ]),
            ),
            const SizedBox(height: 6),
          ],
          const Text('명장 · 천명 진화는 다음 단계에서 추가돼요',
              style: TextStyle(fontSize: 13, color: Color(0xFF3E4248))),
        ],
      ),
    );
  }
}

/// 집기 중 안내 띠: 놓을 곳을 누르세요 + 취소.
class HeldBanner extends StatelessWidget {
  const HeldBanner({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    return BoardSpace(children: [
      Positioned(
        left: 442,
        top: 646,
        width: 520,
        child: ValueListenableBuilder<int>(
          valueListenable: game.changes,
          builder: (context, _, __) {
            final u = game.heldUnit;
            final picking = game.pickingRally;
            if (u == null && !picking) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xEB2A2F35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(picking ? '집결지로 쓸 곳을 누르세요' : '${u!.title}: 놓을 곳을 누르세요',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                SizedBox(
                  height: 44,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2A2F35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: game.cancelHeld,
                    child: const Text('취소'),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

/// 궁 창: 병과별 보급 방향 (소환 / 막사로).
class PalaceDialog extends StatelessWidget {
  const PalaceDialog({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2A2F35);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: game.closePalace,
            child: const ColoredBox(color: Color(0x26141812)),
          ),
        ),
        BoardSpace(children: [
          Positioned(
            left: 412,
            top: 110,
            width: 580,
            child: ValueListenableBuilder<int>(
              valueListenable: game.changes,
              builder: (context, _, __) {
                Widget seg(String label, bool on, VoidCallback tap) => Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: on ? ink : Colors.white,
                            foregroundColor: on ? Colors.white : ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFFC9C3B3)),
                            ),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: tap,
                          child: Text(label),
                        ),
                      ),
                    );
                return Material(
                  color: const Color(0xEBFBF8F1),
                  elevation: 12,
                  shadowColor: const Color(0x47000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFF8C2F2B), width: 3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Text('궁 · 뽑기 설정',
                              style: TextStyle(
                                  fontFamily: 'GowunBatang',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8C2F2B))),
                          const Spacer(),
                          _RoundClose(onTap: game.closePalace),
                        ]),
                        const SizedBox(height: 6),
                        const Text('뽑기로 나온 유닛이 어디로 갈지 병과별로 정해요. 소환된 유닛은 집결지(깃발) 주변으로 모이고, 막사 안 유닛은 공격하지 않아요.',
                            style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF3E4248))),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8C2F2B),
                              side: const BorderSide(color: Color(0xFF8C2F2B), width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            onPressed: game.startPickRally,
                            icon: const Icon(Icons.flag),
                            label: const Text('집결지 바꾸기 (소환된 유닛이 모이는 곳)'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          seg('전체 소환', Rules.branches.every((b) => !game.supplyToBarracks[b]!),
                              () => game.setAllSupply(false)),
                          const SizedBox(width: 8),
                          seg('전체 막사로', Rules.branches.every((b) => game.supplyToBarracks[b]!),
                              () => game.setAllSupply(true)),
                        ]),
                        const SizedBox(height: 10),
                        for (final b in Rules.branches) ...[
                          Row(children: [
                            SizedBox(
                              width: 96,
                              child: Text(b,
                                  style: TextStyle(
                                      fontSize: 19, fontWeight: FontWeight.w700, color: branchColor(b))),
                            ),
                            seg('소환 (맵에 배치)', !game.supplyToBarracks[b]!, () => game.setSupply(b, false)),
                            const SizedBox(width: 8),
                            seg('막사로', game.supplyToBarracks[b]!, () => game.setSupply(b, true)),
                          ]),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ],
    );
  }
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
