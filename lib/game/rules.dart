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

  /// 막사 안 군졸·정병·군관은 화력 절반 (배치한 장수가 주력이 되도록).
  static const double barracksDamage = 0.5;

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
  /// 10R: 장수 없이 5강이면 약 8초, 강화 0이면 대부분 실패 (보스는 선두라 막사 화력을 다 받음).
  /// 20R: 막사만이면 약 10% 통과, 장수를 계속 뽑으면 약 90% 통과.
  /// 30R 이후는 명장이 들어간 뒤 다시 맞출 임시값 (예전 값 × 0.5).
  static const List<double> bossHp = [1800, 4000, 10000, 17000, 25000, 35000];

  // ── 은냥 · 강화 (기획표 '은냥·강화' 탭) ──
  static const List<int> silverPerKill = [2, 3, 4, 6, 8, 10]; // 스테이지별 1마리당
  static const List<String> upgradeNames = ['군졸~군관', '장수', '명장', '천명', '공신'];
  static const List<int> upgradeBase = [10, 20, 30, 40, 50];
  static const List<int> upgradeStep = [3, 5, 8, 10, 12];
  /// 등급별 최대 강화 (군졸~군관은 10강까지, 나머지 20강).
  static const List<int> upgradeMax = [10, 20, 20, 20, 20];
  static const double upgradeChance = 0.5;
  static const double atkPerLv = 0.05;
  static const double speedPerLv = 0.02;
  static const List<int> sellPrice = [5, 15, 45]; // 군졸, 정병, 군관

  /// 일반 몬스터 체력 (기획표 '몬스터' 탭 1–50R). 막사 병사 화력 절반에 맞춘 값.
  /// 1–3R은 군졸만으로 정리, 4–5R은 조금 쌓임, 6R부터 다시 정리. 11R부터는 장수가 있어야 버팀.
  static const List<double> normalHpTable = [
    10, 20, 30, 70, 80, 40, 50, 60, 70, 80,
    220, 255, 290, 340, 390, 435, 490, 540, 585, 630,
    645, 710, 790, 870, 950, 1040, 1140, 1240, 1350, 1455,
    1125, 1210, 1280, 1360, 1430, 1520, 1620, 1725, 1860, 1990,
    1665, 1770, 1880, 1990, 2100, 2210, 2320, 2445, 2595, 2750,
  ];

  /// 51–60R은 기획표에 아직 없어서 50R 값에서 늘려 둔 임시값.
  static double normalHp(int r) {
    if (r <= normalHpTable.length) return normalHpTable[r - 1];
    return 2750 + (3750 - 2750) * (r - 50) / 10;
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
