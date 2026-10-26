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
  /// 보스 체력 (임시): 새 규칙에 맞춰 다시 맞출 예정.
  static const List<double> bossHp = [1260, 1600, 4000, 6800, 10000, 14000];

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

  /// 일반 몬스터 체력 (임시): 막사 안 유닛은 공격하지 않고 맵에 나온 유닛만 싸우는 규칙에 맞춘 임시값.
  /// 소환 위치 · 몬스터 간격을 정한 뒤 시뮬레이터로 다시 맞춘다.
  static const List<double> normalHpTable = [
    5, 10, 20, 50, 60, 30, 35, 40, 50, 55,
    85, 100, 115, 135, 155, 175, 195, 215, 235, 250,
    260, 285, 315, 350, 380, 415, 455, 495, 540, 580,
    450, 485, 515, 545, 575, 610, 650, 690, 745, 795,
    665, 710, 755, 795, 840, 885, 925, 980, 1040, 1100,
  ];

  /// 51–60R은 기획표에 아직 없어서 50R 값에서 늘려 둔 임시값.
  static double normalHp(int r) {
    if (r <= normalHpTable.length) return normalHpTable[r - 1];
    return 1100 + (1500 - 1100) * (r - 50) / 10;
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
