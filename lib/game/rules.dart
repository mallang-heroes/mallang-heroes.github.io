import 'dart:math' as math;

/// 기획표(결정 필요·병과 특성·몬스터 탭) 수치를 옮겨 둔 곳. 밸런스 조정은 여기서.
class Rules {
  static const double roundSeconds = 10;
  static const int lastRound = 60;
  /// 라운드당 10마리를 0.8초 간격으로, 길을 2줄로 나눠 걷는다 (몬스터가 겹치지 않게).
  static const int mobsPerRound = 10;
  static const double spawnGap = 0.8;
  static const double laneOffset = 11; // 길 가운데에서 좌우로

  /// 몬스터 그림 크기 배율 (일반 / 보스).
  static const double mobScale = 1.35;
  static const double bossScale = 1.2;
  /// 필드 몬스터가 이 수를 넘으면 패배 (라운드 5개 분량).
  static const int loseCount = 50;

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
  /// 보스 체력. 10R 800: 집결지 그대로 두는 판 약 70% 통과.
  /// 20R 2,600: 10R을 넘긴 판 중 장수 없음 9% · 장수 1명 62% · 장수 계속 89% 통과.
  /// 30R 이후는 명장이 들어간 뒤 다시 맞출 임시값.
  static const List<double> bossHp = [800, 2600, 6500, 11000, 16000, 22000];

  // ── 은냥 · 강화 (기획표 '은냥·강화' 탭) ──
  static const List<int> silverPerKill = [4, 6, 8, 12, 16, 20]; // 스테이지별 1마리당 (마릿수 절반이라 2배)
  static const List<String> upgradeNames = ['군졸~군관', '장수', '명장', '천명', '공신'];
  static const List<int> upgradeBase = [10, 20, 30, 40, 50];
  static const List<int> upgradeStep = [3, 5, 8, 10, 12];
  /// 등급별 최대 강화 (군졸~군관은 10강까지, 나머지 20강).
  static const List<int> upgradeMax = [10, 20, 20, 20, 20];
  static const double upgradeChance = 0.5;
  static const double atkPerLv = 0.05;
  static const double speedPerLv = 0.02;
  /// 판매가: 뽑기 20냥 기준 군졸 절반, 정병·군관은 재료 수(3배씩)에 맞춤.
  static const List<int> sellPrice = [10, 30, 90]; // 군졸, 정병, 군관

  // ── 준비 라운드 · 뽑기 · 라운드 보너스 ──
  /// 1라운드 전에 주는 준비 시간(초). 이때 시작 은냥과 무료 뽑기권으로 첫 유닛을 뽑는다.
  static const double prepSeconds = 10;
  static const int startSilver = 100;
  /// 뽑기 1회 비용. 무작위 병과 군졸 1명.
  static const int drawCost = 20;
  /// 무료 뽑기권: 시작할 때 1장, 라운드가 시작될 때마다 1장, 최대 3장까지 쌓인다.
  static const int startFreeDraws = 1;
  static const int freeDrawsPerRound = 1;
  static const int maxFreeDraws = 3;
  /// 라운드를 넘길 때 받는 보너스. 예전 무료 보급(라운드당 4명) 중 3명을 뽑기로 사는 몫(3 × 20냥).
  static const int roundClearBonus = 60;

  /// 일반 몬스터 체력 (라운드당 10마리, 맵에 나온 유닛만 공격하는 규칙 기준. 시뮬레이터로 맞춤).
  /// 1–3R 정리, 4–5R 조금 쌓임, 6R 회복. 11–30R은 기존 곡선 × 0.8.
  static const List<double> normalHpTable = [
    10, 25, 40, 100, 115, 55, 70, 85, 100, 110,
    230, 270, 310, 360, 415, 465, 520, 575, 625, 670,
    690, 760, 840, 930, 1015, 1110, 1215, 1320, 1440, 1550,
    1200, 1290, 1370, 1450, 1530, 1625, 1730, 1840, 1985, 2120,
    1775, 1890, 2010, 2120, 2240, 2360, 2470, 2610, 2770, 2935,
  ];

  /// 51–60R은 기획표에 아직 없어서 50R 값에서 늘려 둔 임시값.
  static double normalHp(int r) {
    if (r <= normalHpTable.length) return normalHpTable[r - 1];
    return 2935 + (4000 - 2935) * (r - 50) / 10;
  }

  /// 피해 = 공격력 × 100 / (100 + 방어력)
  static double mitigate(double dmg, double def) => dmg * 100 / (100 + math.max(0, def));
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
