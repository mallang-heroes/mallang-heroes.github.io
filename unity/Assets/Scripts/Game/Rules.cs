using System.Collections.Generic;
using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// 기획표 수치 (Flutter lib/game/rules.dart 그대로 옮김). 밸런스 조정은 여기서.
    /// </summary>
    public static class Rules
    {
        public const float RoundSeconds = 10;
        public const int LastRound = 60;
        /// 라운드당 10마리를 1초 간격으로, 길을 2줄로 나눠 걷는다.
        public const int MobsPerRound = 10;
        public const float SpawnGap = 1.0f;
        public const float LaneOffset = 11; // 길 가운데에서 좌우로

        /// 궁 체력: 일반 몬스터가 궁에 닿을 때마다 1씩 줄고 0이면 패배. 보스가 닿으면 바로 패배.
        public const int PalaceHp = 20;

        public static readonly string[] TierNames = { "군졸", "정병", "군관", "장수" };
        public static readonly string[] TierKeys = { "gunjol", "jeongbyeong", "gungwan", "jangsu" };

        /// 등급 화력 배수 (군졸 = 1).
        public static readonly float[] TierPower = { 1, 3.3f, 11, 45 };

        /// 군졸 평균 DPS가 약 10이 되도록 맞춘 공통 배수.
        public const float DamageScale = 2.2f;
        public const float CritMultiplier = 2;
        public const int AoeTargets = 3;

        public static readonly Dictionary<string, BranchStat> Stats = new Dictionary<string, BranchStat>
        {
            ["창병"] = new BranchStat(3, 1.2f, 1, 0.8f, false),
            ["궁병"] = new BranchStat(2, 1.5f, 1.5f, 0.5f, false),
            ["포수"] = new BranchStat(1, 1.5f, 1.5f, 0.8f, true),
            ["기병"] = new BranchStat(2.5f, 1, 1.5f, 0.8f, false),
            ["수군"] = new BranchStat(1.7f, 1.5f, 1, 0.5f, true),
            ["술사"] = new BranchStat(1.5f, 1, 1.5f, 0.8f, true),
        };

        /// 사거리 반경(보드 px) = 95 + (사거리 − 1) × 36
        public static float RangeRadius(string branch) => 95 + (Stats[branch].Range - 1) * 36;

        public static int Stage(int round) => Mathf.Min((round - 1) / 10, 5);

        public static readonly float[] NormalDefense = { 0, 10, 30, 80, 130, 200 };
        public static readonly float[] BossDefense = { 20, 40, 80, 150, 220, 300 };
        /// 보스 체력. 30R 이후는 명장이 들어간 뒤 다시 맞출 임시값.
        public static readonly float[] BossHp = { 800, 2600, 6500, 11000, 16000, 22000 };

        // ── 은냥 · 강화 ──
        public static readonly int[] SilverPerKill = { 4, 6, 8, 12, 16, 20 };
        public static readonly string[] UpgradeNames = { "군졸~군관", "장수", "명장", "천명", "공신" };
        public static readonly int[] UpgradeBase = { 10, 20, 30, 40, 50 };
        public static readonly int[] UpgradeStep = { 3, 5, 8, 10, 12 };
        /// 등급별 최대 강화 (군졸~군관은 10강까지, 나머지 20강).
        public static readonly int[] UpgradeMax = { 10, 20, 20, 20, 20 };
        public const float UpgradeChance = 0.5f;
        public const float AtkPerLv = 0.05f;
        public const float SpeedPerLv = 0.02f;
        /// 판매가: 군졸, 정병, 군관
        public static readonly int[] SellPrice = { 10, 30, 90 };

        // ── 준비 라운드 · 뽑기 · 라운드 보너스 ──
        public const float PrepSeconds = 10;
        public const int StartSilver = 100;
        public const int DrawCost = 20;
        public const int StartFreeDraws = 1;
        public const int FreeDrawsPerRound = 1;
        public const int MaxFreeDraws = 3;
        public const int RoundClearBonus = 60;

        public static readonly float[] NormalHpTable =
        {
            10, 25, 40, 100, 115, 55, 70, 85, 100, 110,
            230, 270, 310, 360, 415, 465, 520, 575, 625, 670,
            690, 760, 840, 930, 1015, 1110, 1215, 1320, 1440, 1550,
            1200, 1290, 1370, 1450, 1530, 1625, 1730, 1840, 1985, 2120,
            1775, 1890, 2010, 2120, 2240, 2360, 2470, 2610, 2770, 2935,
        };

        /// 51–60R은 기획표에 아직 없어서 50R 값에서 늘려 둔 임시값.
        public static float NormalHp(int r)
        {
            if (r <= NormalHpTable.Length) return NormalHpTable[r - 1];
            return 2935 + (4000 - 2935) * (r - 50) / 10f;
        }

        /// 피해 = 공격력 × 100 / (100 + 방어력)
        public static float Mitigate(float dmg, float def) => dmg * 100 / (100 + Mathf.Max(0, def));
    }

    public readonly struct BranchStat
    {
        public readonly float Atk;
        public readonly float Speed; // 초당 공격 횟수
        public readonly float Range;
        public readonly float Crit; // 치명 확률 0–1
        public readonly bool Aoe;

        public BranchStat(float atk, float speed, float range, float crit, bool aoe)
        {
            Atk = atk; Speed = speed; Range = range; Crit = crit; Aoe = aoe;
        }
    }
}
