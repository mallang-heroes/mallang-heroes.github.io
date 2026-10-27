import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/board.dart';
import '../game/hud.dart';
import '../game/mallang_game.dart';
import '../game/rules.dart';
import '../game/sheets.dart';
import '../game/units.dart';

// ── 공통 색 (먹색 패널 + 금색 강조) ──
const _ink = Color(0xFF2A211C);
const _panel = Color(0xEB2A211C);
const _panelLine = Color(0xFF4A3B30);
const _card = Color(0xFF3A2F28);
const _cream = Color(0xFFFFF6E0);
const _sub = Color(0xFFE9DCC0);
const _muted = Color(0xFFB9AC95);
const _dim = Color(0xFF7D7262);
const _gold = Color(0xFFF2C14E);
const _goldDark = Color(0xFFB8891E);
const _paperBtn = Color(0xFFF5E8C8);
const _paperShade = Color(0xFFD9C59A);
const _red = Color(0xFFE0483E);
const _sky = Color(0xFF8EC7F0);
const _paper = Color(0xF2FBF8F1);

TextStyle _t(double size, Color color, {bool bold = true, double? height}) => TextStyle(
      fontFamily: 'Pretendard',
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

BoxDecoration _panelBox({double radius = 12}) => BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _panelLine, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 3))],
    );

/// 게임 화면 전체: 위쪽 맵(+정보줄·알림) / 아래 트레이. 넓은 화면에서는 가운데에 폰 폭으로.
class GameShell extends StatelessWidget {
  const GameShell({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GameWidget<MallangGame>(
                      game: game,
                      overlayBuilderMap: {
                        'detail': (context, g) => DetailDialog(game: g),
                        'held': (context, g) => HeldBanner(game: g),
                        'result': (context, g) => const SizedBox.shrink(),
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(bottom: false, child: StatusBar(game: game)),
                  ),
                  Positioned(left: 0, right: 0, bottom: 10, child: ToastView(game: game)),
                ],
              ),
            ),
            Tray(game: game),
          ],
        ),
        ValueListenableBuilder<int>(
          valueListenable: game.changes,
          builder: (context, _, __) =>
              game.phase == Phase.playing ? const SizedBox.shrink() : ResultDialog(game: game),
        ),
      ],
    );
  }
}

// ── 위쪽 정보줄 ──

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: ValueListenableBuilder<int>(
        valueListenable: game.changes,
        builder: (context, _, __) {
          final prep = game.preparing;
          final bossAlive = game.boss != null && !game.boss!.dead;
          final String timer;
          final double ratio;
          if (prep) {
            timer = '전투 시작까지 ${game.prepLeft.ceil()}초';
            ratio = game.prepLeft / Rules.prepSeconds;
          } else if (game.round >= Rules.lastRound) {
            timer = bossAlive ? '마지막 보스!' : '남은 몬스터를 막아요';
            ratio = 1;
          } else {
            final left = (Rules.roundSeconds - game.roundTime).clamp(0, Rules.roundSeconds);
            timer = bossAlive ? '보스 등장! · 다음 ${left.ceil()}초' : '다음 라운드 ${left.ceil()}초';
            ratio = game.roundTime / Rules.roundSeconds;
          }
          return SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: _panelBox(),
                    padding: const EdgeInsets.fromLTRB(5, 0, 10, 0),
                    child: Row(children: [
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: prep ? _sky : _gold, borderRadius: BorderRadius.circular(7)),
                        child: prep
                            ? Text('준비', style: _t(14, _ink))
                            : Text.rich(TextSpan(children: [
                                TextSpan(text: '${game.round}', style: _t(15, _ink)),
                                TextSpan(text: ' / ${Rules.lastRound}', style: _t(11, const Color(0xBF2A211C))),
                              ])),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(timer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _t(11, bossAlive ? const Color(0xFFFF9B8F) : _sub, bold: false)),
                            const SizedBox(height: 3),
                            _Bar(ratio: ratio, color: _sky, height: 4),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: _panelBox(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Text('궁', style: _t(11, _sub, bold: false)),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 40,
                      child: _Bar(
                          ratio: game.palaceHp / Rules.palaceHp,
                          color: game.palaceHp <= 5 ? _red : const Color(0xFF6FCF6A),
                          height: 7),
                    ),
                    const SizedBox(width: 5),
                    Text('${game.palaceHp}', style: _t(13, _cream)),
                  ]),
                ),
                const SizedBox(width: 6),
                _CoinPill(game: game),
                const SizedBox(width: 6),
                _PressButton(
                  onTap: game.toggleSpeed,
                  semantics: '게임 속도 ${game.gameSpeed.toInt()}배',
                  child: Container(
                    width: 46,
                    decoration: _panelBox().copyWith(color: game.gameSpeed > 1 ? const Color(0xEB2E5E8C) : _panel),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fast_forward_rounded, size: 15, color: _gold),
                      Text('×${game.gameSpeed.toInt()}', style: _t(13, _cream)),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.ratio, required this.color, this.height = 6});
  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 40.0;
      final r = BorderRadius.circular(height / 2);
      return Container(
        width: w,
        height: height,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: const Color(0x2EFFF6E0), borderRadius: r),
        child: Container(
          width: w * ratio.clamp(0.0, 1.0),
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: r),
        ),
      );
    });
  }
}

/// 은냥: 엽전 + 숫자. 엽전이 도착하면 톡 커진다.
class _CoinPill extends StatefulWidget {
  const _CoinPill({required this.game});
  final MallangGame game;

  @override
  State<_CoinPill> createState() => _CoinPillState();
}

class _CoinPillState extends State<_CoinPill> with SingleTickerProviderStateMixin {
  late final AnimationController _bump =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    widget.game.coinBump.addListener(_onCoin);
  }

  void _onCoin() => _bump.forward(from: 0);

  @override
  void dispose() {
    widget.game.coinBump.removeListener(_onCoin);
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelBox(radius: 17),
      padding: const EdgeInsets.fromLTRB(5, 0, 11, 0),
      child: Row(children: [
        AnimatedBuilder(
          animation: _bump,
          builder: (context, child) =>
              Transform.scale(scale: 1 + 0.25 * math.sin(_bump.value * math.pi), child: child),
          child: const _Coin(size: 20),
        ),
        const SizedBox(width: 4),
        Text('${widget.game.silver}', style: _t(15, Colors.white)),
      ]),
    );
  }
}

/// 엽전 그림 (게임 안 엽전과 같은 모양).
class _Coin extends StatelessWidget {
  const _Coin({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) =>
      drawYeopjeon(canvas, Offset(size.width / 2, size.height / 2), size.width * 0.45);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 맵 아래쪽 알림 띠.
class ToastView extends StatelessWidget {
  const ToastView({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<int>(
        valueListenable: game.changes,
        builder: (context, _, __) {
          final t = game.toastText;
          return AnimatedOpacity(
            opacity: t == null ? 0 : 1,
            duration: const Duration(milliseconds: 160),
            child: Center(
              child: t == null
                  ? const SizedBox(height: 32)
                  : Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: _panelBox(radius: 16),
                      alignment: Alignment.center,
                      child: Text(t, style: _t(13, _cream)),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ── 아래 트레이: 왼쪽 탭 내용 + 오른쪽 탭 4개·뽑기 ──

class Tray extends StatelessWidget {
  const Tray({super.key, required this.game});
  final MallangGame game;

  static const double contentHeight = 246;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _panelLine, width: 2)),
        boxShadow: [BoxShadow(color: Color(0x2E000000), offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
      child: SizedBox(
        height: contentHeight,
        child: ValueListenableBuilder<int>(
          valueListenable: game.changes,
          builder: (context, _, __) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _panelLine, width: 2),
                  ),
                  padding: const EdgeInsets.all(8),
                  clipBehavior: Clip.antiAlias,
                  child: _content(),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(width: 76, child: _side()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final open = game.openBranch;
    return switch (game.tab) {
      TrayTab.barracks =>
        open == null ? _BarracksGrid(game: game) : _BarracksInside(game: game, branch: open),
      TrayTab.upgrade => _UpgradePanel(game: game),
      TrayTab.relic => const _EmptyNote(
          icon: Icons.diamond_outlined, title: '아직 얻은 유물이 없어요', sub: '얻은 유물만 여기에 보여요'),
      TrayTab.effect => const _EmptyNote(
          icon: Icons.auto_awesome, title: '적용 중인 유물 효과가 없어요', sub: '유물을 얻으면 효과가 합쳐져서 보여요'),
    };
  }

  Widget _side() {
    const tabs = [
      (TrayTab.barracks, '막사', Icons.holiday_village_rounded),
      (TrayTab.upgrade, '강화', Icons.upgrade_rounded),
      (TrayTab.relic, '유물', Icons.diamond_outlined),
      (TrayTab.effect, '효과', Icons.auto_awesome),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (t, label, icon) in tabs) ...[
          _TabButton(
            label: label,
            icon: icon,
            on: game.tab == t,
            dot: t == TrayTab.barracks && game.barracksDot,
            onTap: () => game.selectTab(t),
          ),
          const SizedBox(height: 5),
        ],
        Expanded(child: _DrawButton(game: game)),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.icon, required this.on, required this.dot, required this.onTap});
  final String label;
  final IconData icon;
  final bool on;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = on ? _ink : _sub;
    return _PressButton(
      onTap: onTap,
      semantics: label,
      child: SizedBox(
        height: 38,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: on ? _gold : _card,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: on ? _ink : _panelLine, width: 2),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 3),
                Text(label, style: _t(12, fg)),
              ]),
            ),
          ),
          if (dot)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: _red,
                  shape: BoxShape.circle,
                  border: Border.all(color: _ink, width: 2),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// 뽑기: 무료권이 있으면 빨간 '무료 n' 배지와 금빛 테두리, 없으면 비용, 못 뽑으면 회색.
class _DrawButton extends StatelessWidget {
  const _DrawButton({required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    final free = game.freeDraws;
    final can = game.canDraw;
    final fg = can ? _ink : _dim;
    return _PressButton(
      onTap: game.draw,
      semantics: free > 0 ? '무료 뽑기, $free장 남음' : '뽑기, ${Rules.drawCost}냥',
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: can
                  ? const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE08A), _gold])
                  : null,
              color: can ? null : _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _ink, width: 2),
              boxShadow: free > 0
                  ? const [BoxShadow(color: Color(0x66F2C14E), spreadRadius: 3)]
                  : (can ? const [BoxShadow(color: Color(0xFFC99A2E), offset: Offset(0, 3))] : null),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.redeem_rounded, size: 22, color: fg),
              Text('뽑기', style: _t(16, fg)),
              const SizedBox(height: 1),
              if (free > 0)
                Text('무료', style: _t(11, const Color(0xFF8C2F2B)))
              else if (can)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const _Coin(size: 13),
                  const SizedBox(width: 2),
                  Text('${Rules.drawCost}', style: _t(11, const Color(0xFF6B4A10))),
                ])
              else
                Text('은냥 부족', style: _t(10, fg, bold: false)),
            ]),
          ),
        ),
        if (free > 0)
          Positioned(
            right: -6,
            top: -8,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _ink, width: 2),
              ),
              child: Text('무료 $free', style: _t(11, Colors.white)),
            ),
          ),
      ]),
    );
  }
}

/// 막사 목록: 3×2 카드 (건물 + 등급별 인원 졸·정·관 + 병과 이름).
class _BarracksGrid extends StatelessWidget {
  const _BarracksGrid({required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    final branches = Rules.branches;
    Widget row(int from) => Expanded(
          child: Row(children: [
            for (var i = from; i < from + 3; i++) ...[
              if (i > from) const SizedBox(width: 6),
              Expanded(child: _BarracksCard(game: game, branch: branches[i])),
            ],
          ]),
        );
    return Column(children: [row(0), const SizedBox(height: 6), row(3)]);
  }
}

class _BarracksCard extends StatelessWidget {
  const _BarracksCard({required this.game, required this.branch});
  final MallangGame game;
  final String branch;

  @override
  Widget build(BuildContext context) {
    final b = game.barracks[branch]!;
    final color = branchColor(branch);
    final flash = b.flash > 0;
    final key = Board.branch(branch).key;
    final ready = game.countOf(branch, 0) >= 3 || game.countOf(branch, 1) >= 3 || game.canSummonGeneral(branch);
    return _PressButton(
      onTap: () => game.openBarracks(branch),
      semantics: '$branch 막사, 군졸 ${b.counts[0]} 정병 ${b.counts[1]} 군관 ${b.counts[2]}',
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: flash ? const Color(0xFF4A3B22) : _ink,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: flash ? _gold : color, width: 2),
              boxShadow: flash ? const [BoxShadow(color: Color(0x73F2C14E), spreadRadius: 3)] : null,
            ),
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 6),
            child: Column(children: [
              Expanded(
                child: Image.asset('assets/images/map/map-bld-barracks-$key.webp',
                    fit: BoxFit.contain, filterQuality: FilterQuality.medium),
              ),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var t = 0; t < 3; t++) ...[
                  if (t > 0) const SizedBox(width: 2),
                  _Chip(label: '${const ['졸', '정', '관'][t]}${b.counts[t]}', on: b.counts[t] > 0),
                ],
              ]),
              const SizedBox(height: 7),
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text(branch, style: _t(13, Colors.white)),
              ),
            ]),
          ),
        ),
        if (flash)
          Positioned(
            right: -6,
            top: -8,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _ink, width: 2),
              ),
              child: Text('+1', style: _t(12, _ink)),
            ),
          )
        else if (ready)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
                border: Border.all(color: _ink, width: 1.5),
              ),
              child: const Icon(Icons.arrow_upward_rounded, size: 12, color: _ink),
            ),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? _paperBtn : const Color(0x14FFF6E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: _t(11, on ? _ink : _dim)),
    );
  }
}

/// 막사 안: 군졸·정병·군관 카드(배치·판매) + 승진·장수 소환.
class _BarracksInside extends StatelessWidget {
  const _BarracksInside({required this.game, required this.branch});
  final MallangGame game;
  final String branch;

  @override
  Widget build(BuildContext context) {
    final b = game.barracks[branch]!;
    final color = branchColor(branch);
    final all = [for (var t = 0; t < 3; t++) game.countOf(branch, t)];
    final have = [0, 1, 2].where((t) => all[t] > 0).length;
    final sheets = game.tierIdle[branch];
    final actions = [
      ('정병 승진 ${all[0].clamp(0, 3)}/3', all[0] >= 3, false, () => game.promote(branch, 0)),
      ('군관 승진 ${all[1].clamp(0, 3)}/3', all[1] >= 3, false, () => game.promote(branch, 1)),
      ('장수 소환 $have/3', have == 3, true, () => game.summonGeneral(branch)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: Row(children: [
            _PressButton(
              onTap: game.closeBarracks,
              semantics: '막사 목록으로',
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _panelLine, width: 2),
                ),
                alignment: Alignment.center,
                child: Row(children: [
                  const Icon(Icons.chevron_left_rounded, size: 16, color: _sub),
                  Text('막사 목록', style: _t(12, _sub)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
              child: Text('$branch 막사', style: _t(13, Colors.white)),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var t = 0; t < 3; t++) ...[
              if (t > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _panelLine, width: 2),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(children: [
                    Expanded(
                      child: SheetView(sheet: sheets?[t], color: color, width: 60, height: 50, dim: b.counts[t] == 0),
                    ),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '${Rules.tierNames[t]} ', style: _t(13, _cream)),
                      TextSpan(text: '×${b.counts[t]}', style: _t(13, _gold)),
                    ])),
                    Text(game.fieldCount(branch, t) > 0 ? '맵에 ${game.fieldCount(branch, t)}명' : '맵에 없음',
                        style: _t(10, _muted, bold: false)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: _SmallButton(
                          label: '배치',
                          enabled: b.counts[t] > 0,
                          filled: true,
                          onTap: () => game.takeOut(branch, t),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: _SmallButton(
                          label: '+${Rules.sellPrice[t]}냥',
                          enabled: b.counts[t] > 0,
                          filled: false,
                          onTap: () => game.sell(branch, t),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: Row(children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _PressButton(
                  onTap: actions[i].$2 ? actions[i].$4 : null,
                  semantics: actions[i].$1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: actions[i].$2 ? (actions[i].$3 ? color : _paperBtn) : _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: actions[i].$2 ? _ink : _panelLine, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(actions[i].$1,
                        style: _t(13, actions[i].$2 ? (actions[i].$3 ? Colors.white : _ink) : _dim)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.enabled, required this.filled, required this.onTap});
  final String label;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressButton(
      onTap: enabled ? onTap : null,
      semantics: label,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled && enabled ? _paperBtn : _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: filled && enabled ? _ink : _panelLine, width: 1.5),
        ),
        child: Text(label, style: _t(filled ? 13 : 12, enabled ? (filled ? _ink : _sub) : _dim)),
      ),
    );
  }
}

/// 강화: 군졸~군관 · 장수 (명장·천명·공신은 잠김).
class _UpgradePanel extends StatelessWidget {
  const _UpgradePanel({required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    Widget big(int g) {
      final lv = game.upgradeLv[g];
      final max = Rules.upgradeMax[g];
      final maxed = lv >= max;
      final can = game.canUpgrade(g);
      return Expanded(
        child: _PressButton(
          onTap: can ? () => game.tryUpgrade(g) : null,
          semantics: '${Rules.upgradeNames[g]} 강화',
          child: Container(
            decoration: BoxDecoration(
              color: can ? _paperBtn : (maxed ? const Color(0xFFD3E6C8) : const Color(0xFFDCD7CD)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: can ? _goldDark : _ink, width: 2),
              boxShadow: can ? const [BoxShadow(color: _paperShade, offset: Offset(0, 3))] : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(Rules.upgradeNames[g], style: _t(17, _ink)),
              const SizedBox(height: 2),
              Text('Lv $lv / $max', style: _t(13, const Color(0xFF5E4E3F))),
              const SizedBox(height: 6),
              _Bar(ratio: lv / max, color: maxed ? const Color(0xFF6E8A5A) : _goldDark, height: 5),
              const SizedBox(height: 6),
              if (maxed)
                Text('최대 강화', style: _t(13, const Color(0xFF4F6B3E)))
              else
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const _Coin(size: 15),
                  const SizedBox(width: 3),
                  Text('${game.upgradeCost(g)}',
                      style: _t(13, can ? const Color(0xFF6B4A10) : const Color(0xFFB0473F))),
                  const SizedBox(width: 8),
                  Text('성공 ${(Rules.upgradeChance * 100).round()}%', style: _t(12, const Color(0xFF5E4E3F), bold: false)),
                ]),
            ]),
          ),
        ),
      );
    }

    Widget locked(int g) => Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E1814), width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_rounded, size: 16, color: _muted),
              const SizedBox(height: 4),
              Text(Rules.upgradeNames[g], style: _t(13, _muted)),
            ]),
          ),
        );

    return Column(children: [
      Expanded(flex: 13, child: Row(children: [big(0), const SizedBox(width: 6), big(1)])),
      const SizedBox(height: 6),
      Expanded(
        flex: 9,
        child: Row(children: [locked(2), const SizedBox(width: 6), locked(3), const SizedBox(width: 6), locked(4)]),
      ),
    ]);
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 32, color: _dim),
        const SizedBox(height: 8),
        Text(title, style: _t(14, _sub)),
        const SizedBox(height: 4),
        Text(sub, style: _t(12, _muted, bold: false)),
      ]),
    );
  }
}

/// 누르면 살짝 눌리는 버튼 (onTap이 null이면 비활성).
class _PressButton extends StatefulWidget {
  const _PressButton({required this.onTap, required this.child, required this.semantics});
  final VoidCallback? onTap;
  final Widget child;
  final String semantics;

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 80),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 스프라이트 시트를 Flutter 화면에서 반복 재생 (막사 안·상세 창).
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
    if (dim) canvas.saveLayer(null, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.35));
    final s = sheet;
    if (s == null) {
      // 그림을 아직 못 받았을 때: 통통 튀는 임시 슬라임
      final bob = math.sin(t * 4) * 2;
      final body = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.62 + bob), width: size.width * 0.6, height: size.height * 0.55);
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

/// 유닛 상세 창: 맵 아래쪽에 뜨는 카드 (그림 · 이름 · 정보 · 승진/조합 · 집기 · 막사로 보내기).
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
            child: const ColoredBox(color: Color(0x33141812)),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: ValueListenableBuilder<int>(
            valueListenable: game.changes,
            builder: (context, _, __) {
              final u = game.detailUnit;
              if (u == null) return const SizedBox.shrink();
              return combo && u.tier >= 3 ? _comboPanel(game, u) : _detail(game, u);
            },
          ),
        ),
      ],
    );
  }

  Widget _detail(MallangGame game, FieldUnit u) {
    final color = branchColor(u.branch);
    final st = Rules.stats[u.branch]!;
    final lv = game.upgradeLv[u.group];
    final isGeneral = u.tier >= 3;
    final atk = st.atk * Rules.damageScale * u.power;
    final range = st.range == st.range.roundToDouble() ? '${st.range.toInt()}' : '${st.range}';
    final sheet = game.fieldArt[u.branch]?[u.tier]?.idle;

    final int have;
    final String nextLabel;
    if (u.tier < 2) {
      have = game.countOf(u.branch, u.tier).clamp(0, 3);
      nextLabel = '${Rules.tierNames[u.tier + 1]} 승진 $have/3';
    } else {
      have = [0, 1, 2].where((t) => game.countOf(u.branch, t) > 0).length;
      nextLabel = '장수 소환 $have/3';
    }
    final canNext = have >= 3;

    Widget stat(String label, String value) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label ', style: _t(12, _muted, bold: false)),
            TextSpan(text: value, style: _t(13, _cream)),
          ])),
        );

    return Container(
      decoration: _panelBox(radius: 16).copyWith(border: Border.all(color: color, width: 2)),
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 76,
            height: 86,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Center(child: SheetView(sheet: sheet, color: Colors.white, width: 64, height: 74)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(u.title, style: _t(18, Colors.white))),
                _PressButton(
                  onTap: game.closeDetail,
                  semantics: '닫기',
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.close_rounded, size: 22, color: _sub),
                  ),
                ),
              ]),
              Wrap(runSpacing: 2, children: [
                stat('공격력', atk.toStringAsFixed(0)),
                stat('초당', '${(st.speed * game.speedMul(u.group)).toStringAsFixed(2)}회'),
                stat('사거리', range),
                stat('치명', '${(st.crit * 100).round()}%'),
                stat('강화', '$lv/${Rules.upgradeMax[u.group]}'),
              ]),
              const SizedBox(height: 2),
              Text(st.aoe ? '광역: 사거리 안 맨 앞부터 3마리' : '단일: 사거리 안 맨 앞 1마리',
                  style: _t(11, _muted, bold: false)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: Row(children: [
            Expanded(
              child: _PressButton(
                onTap: isGeneral ? () => setState(() => combo = true) : (canNext ? () => game.promoteFrom(u) : null),
                semantics: isGeneral ? '조합하기' : nextLabel,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isGeneral || canNext ? _paperBtn : _card,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: isGeneral || canNext ? _goldDark : _panelLine, width: 2),
                  ),
                  child: Text(isGeneral ? '조합하기' : nextLabel,
                      style: _t(14, isGeneral || canNext ? const Color(0xFF7A5A10) : _dim)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PressButton(
                onTap: game.pickUp,
                semantics: '집기',
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _ink, width: 2),
                  ),
                  child: Text('집기 (칸 옮기기)', style: _t(14, _ink)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: isGeneral
              ? Center(child: Text('장수는 막사에 들어가지 않고 맵에서 싸워요', style: _t(12, _muted, bold: false)))
              : _PressButton(
                  onTap: game.sendHome,
                  semantics: '막사로 보내기',
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Text('막사로 보내기 (${u.branch} 막사)', style: _t(13, _sub)),
                  ),
                ),
        ),
      ]),
    );
  }

  /// 조합하기: 명장 A · 명장 B · 천명 레시피와 재료 현황 (진화는 다음 단계에서).
  Widget _comboPanel(MallangGame game, FieldUnit u) {
    final order = Rules.branches;
    final i = order.indexOf(u.branch);
    final next = order[(i + 1) % order.length];
    final prev = order[(i + order.length - 1) % order.length];
    final names = roster[u.branch]!;
    final generals = game.countOf(u.branch, 3);
    final recipes = [
      ('${names[0]} (명장)', '${u.branch} 장수 2 + $next 군관 1',
          (generals >= 2 ? 2 : generals) + (game.countOf(next, 2) > 0 ? 1 : 0)),
      ('${names[1]} (명장)', '${u.branch} 장수 2 + $prev 군관 1',
          (generals >= 2 ? 2 : generals) + (game.countOf(prev, 2) > 0 ? 1 : 0)),
      ('${names[2]} (천명)', '${u.branch} 장수 1 + 천명 유물 (한 판 1명)', 1),
    ];
    return Container(
      decoration: _panelBox(radius: 16).copyWith(border: Border.all(color: _goldDark, width: 2)),
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('조합하기', style: _t(17, _gold)),
          const Spacer(),
          _PressButton(
            onTap: () => setState(() => combo = false),
            semantics: '닫기',
            child: const SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, size: 22, color: _sub)),
          ),
        ]),
        for (final r in recipes) ...[
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _panelLine, width: 2),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$1, style: _t(14, _cream)),
                  Text(r.$2, style: _t(11, _muted, bold: false)),
                ]),
              ),
              Text('${r.$3} / 3', style: _t(14, _sub)),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Text('명장 · 천명 진화는 다음 단계에서 추가돼요', style: _t(11, _muted, bold: false)),
      ]),
    );
  }
}

/// 집기 중 안내 띠: 놓을 칸을 누르세요 + 취소.
class HeldBanner extends StatelessWidget {
  const HeldBanner({super.key, required this.game});
  final MallangGame game;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 50),
        child: ValueListenableBuilder<int>(
          valueListenable: game.changes,
          builder: (context, _, __) {
            final u = game.heldUnit;
            if (u == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: _panelBox(radius: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text('${u.title}: 옮길 칸을 누르세요', style: _t(14, _cream))),
                const SizedBox(width: 10),
                _PressButton(
                  onTap: game.cancelHeld,
                  semantics: '취소',
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _paperBtn, borderRadius: BorderRadius.circular(9)),
                    child: Text('취소', style: _t(13, _ink)),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
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
      color: const Color(0x80000000),
      child: Center(
        child: Material(
          color: _paper,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(won ? '승리!' : '궁이 함락됐어요',
                    style: TextStyle(
                        fontFamily: 'GowunBatang',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: won ? const Color(0xFF3F6B3A) : const Color(0xFF8C2F2B))),
                const SizedBox(height: 8),
                Text(game.endReason, style: _t(16, _ink, bold: false)),
                const SizedBox(height: 4),
                Text('${game.round}라운드 · 처치 ${game.kills}', style: _t(14, const Color(0xFF5C6066), bold: false)),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 52),
                    backgroundColor: _ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: game.restart,
                  child: Text('다시 하기', style: _t(18, _cream)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
