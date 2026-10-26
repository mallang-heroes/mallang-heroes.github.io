import 'dart:math' as math;

/// 기획표(결정 필요·병과 특성·몬스터 탭) 수치를 옮겨 둔 곳. 밸런스 조정은 여기서.
class Rules {
  static const double roundSeconds = 10;
  static const int lastRound = 60;
  static const int mobsPerRound = 20;
  static const double spawnGap = 0.4; // 20마리를 8초에 걸쳐 내보냄
  static const int loseCount = 100;

  /// 병과 순서 (막사 왼쪽부터).
  static const List<String> branches = ['창병', '궁병', '포수', '기병', '수군', '술사'];
  static const List<String> tierNames = ['군졸', '정병', '군관', '장수'];

  /// 등급 화력 배수 (군졸 = 1).
  static const List<double> tierPower = [1, 3.3, 11, 45];

  /// 군졸 평균 DPS가 약 10이 되도록 맞춘 공통 배수.
  static const double damageScale = 2.2;
  static const double critMultiplier = 2;
  static const int aoeTargets = 3;

  static const Map<String, BranchStat> stats = {
    '창병': BranchStat(atk: 3, speed: 1.2, range: 1, crit: 0.8, aoe: false),
    '궁병': BranchStat(atk: 2, speed: 1.5, range: 1.5, crit: 0.5, aoe: false),
    '포수': BranchStat(atk: 1, speed: 1.5, range: 1.5, crit: 0.8, aoe: true),
    '기병': BranchStat(atk: 2.5, speed: 1, range: 1.5, crit: 0.8, aoe: false),
    '수군': BranchStat(atk: 1.7, speed: 1.5, range: 1, crit: 0.5, aoe: true),
    '술사': BranchStat(atk: 1.5, speed: 1, range: 1.5, crit: 0.8, aoe: true),
  };

  /// 사거리 반경(px) = 95 + (사거리 − 1) × 36
  static double rangeRadius(String branch) => 95 + (stats[branch]!.range - 1) * 36;

  static int stage(int round) => math.min((round - 1) ~/ 10, 5);

  static const List<double> normalDefense = [0, 10, 30, 80, 130, 200];
  static const List<double> bossDefense = [20, 40, 80, 150, 220, 300];
  static const List<double> bossHp = [2000, 8000, 20000, 34000, 50000, 70000];

  /// 1–10R 일반 몬스터 체력: 1–3R은 군졸만으로 정리, 4–5R은 조금 쌓임, 6R부터 다시 정리.
  static const List<double> earlyHp = [15, 35, 55, 140, 165, 80, 100, 120, 140, 160];

  static double normalHp(int r) {
    double lerp(double a, double b, double t) => a + (b - a) * t;
    if (r <= 10) return earlyHp[r - 1];
    if (r <= 20) return lerp(290, 840, (r - 11) / 9);
    if (r <= 30) return lerp(860, 1940, (r - 21) / 9);
    if (r <= 40) return lerp(1500, 2480, (r - 31) / 8);
    if (r <= 50) return lerp(2220, 3460, (r - 41) / 8);
    return lerp(3670, 5000, (r - 50) / 10);
  }

  /// 피해 = 공격력 × 100 / (100 + 방어력)
  static double mitigate(double dmg, double def) => dmg * 100 / (100 + math.max(0, def));

  /// 보급: 군졸 3 + 보너스 1 (11–30R 10% 정병, 31–60R 10% 군관)
  static List<(String, int)> supply(int round, math.Random rng) {
    final out = <(String, int)>[];
    for (var i = 0; i < 4; i++) {
      final br = branches[rng.nextInt(branches.length)];
      var tier = 0;
      if (i == 3 && rng.nextDouble() < 0.1) {
        if (round >= 31) {
          tier = 2;
        } else if (round >= 11) {
          tier = 1;
        }
      }
      out.add((br, tier));
    }
    return out;
  }
}

class BranchStat {
  final double atk;
  final double speed; // 초당 공격 횟수
  final double range;
  final double crit; // 치명 확률 0–1
  final bool aoe;
  const BranchStat({
    required this.atk,
    required this.speed,
    required this.range,
    required this.crit,
    required this.aoe,
  });
}
