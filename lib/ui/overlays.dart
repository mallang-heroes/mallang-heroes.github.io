import 'package:flutter/material.dart';

import '../game/mallang_game.dart';
import '../game/rules.dart';
import '../game/units.dart';

const _ink = Color(0xFF2A211C);
const _paper = Color(0xF2FBF8F1);

/// 막사 창: 승진 · 장수 소환.
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
            child: const ColoredBox(color: Color(0x26000000)),
          ),
        ),
        Center(
          child: ValueListenableBuilder<int>(
            valueListenable: game.changes,
            builder: (context, _, __) {
              final br = game.selectedBranch;
              if (br == null) return const SizedBox.shrink();
              final b = game.barracks[br]!;
              final color = branchColor(br);
              return FractionallySizedBox(
                widthFactor: 0.5,
                child: Material(
                  color: _paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: color, width: 3),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('$br 막사',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
                            const Spacer(),
                            IconButton(
                              onPressed: game.closeBarracks,
                              icon: const Icon(Icons.close),
                              tooltip: '닫기',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var t = 0; t < 3; t++)
                              Expanded(
                                child: _TierCell(
                                  name: Rules.tierNames[t],
                                  count: b.counts[t],
                                  color: color,
                                  action: t < 2 ? '3명 승진' : null,
                                  enabled: t < 2 && b.counts[t] >= 3,
                                  onTap: () => game.promote(br, t),
                                  sellLabel: '판매 +${Rules.sellPrice[t]}냥',
                                  onSell: b.counts[t] > 0 ? () => game.sell(br, t) : null,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            minimumSize: const Size.fromHeight(52),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          onPressed: b.canSummonGeneral ? () => game.summonGeneral(br) : null,
                          child: const Text('장수 소환 (군관 + 정병 + 군졸)'),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '승진하면 무작위 병과의 다음 등급이 나와요. 막사 병사는 맨 앞 몬스터를 쳐요.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF5C6066)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TierCell extends StatelessWidget {
  const _TierCell({
    required this.name,
    required this.count,
    required this.color,
    required this.action,
    required this.enabled,
    required this.onTap,
    required this.sellLabel,
    required this.onSell,
  });

  final String name;
  final int count;
  final Color color;
  final String? action;
  final bool enabled;
  final VoidCallback onTap;
  final String sellLabel;
  final VoidCallback? onSell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(name, style: const TextStyle(fontSize: 15, color: _ink)),
          Text('$count',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: count > 0 ? color : Colors.black26)),
          const SizedBox(height: 4),
          if (action != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                foregroundColor: color,
                side: BorderSide(color: enabled ? color : Colors.black12, width: 2),
              ),
              onPressed: enabled ? onTap : null,
              child: Text(action!),
            )
          else
            const SizedBox(height: 40),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              foregroundColor: const Color(0xFF5C6066),
            ),
            onPressed: onSell,
            child: Text(sellLabel, style: const TextStyle(fontSize: 13)),
          ),
        ],
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
