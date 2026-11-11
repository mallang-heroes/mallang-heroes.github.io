using System.Collections.Generic;
using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// 보드 좌표 (Flutter lib/game/board.dart 그대로). 세로 화면 585×834, 왼쪽 위가 (0,0), 아래로 갈수록 y가 커진다.
    /// 유니티 월드로는 Board.ToWorld로 바꾼다 (보드 100 = 월드 1, 보드 가운데가 월드 원점, y 뒤집음).
    /// </summary>
    public static class Board
    {
        public const float Width = 585;
        public const float Height = 834;
        public const float UnitsPerWorld = 100;

        public static readonly Branch[] Branches =
        {
            new Branch("창병", "spear", new Color32(0x9A, 0x3B, 0x2E, 0xFF)),
            new Branch("궁병", "archer", new Color32(0x3F, 0x6B, 0x3A, 0xFF)),
            new Branch("포수", "gunner", new Color32(0x5E, 0x4E, 0x8C, 0xFF)),
            new Branch("기병", "cavalry", new Color32(0x8A, 0x64, 0x18, 0xFF)),
            new Branch("수군", "navy", new Color32(0x2E, 0x5E, 0x8C, 0xFF)),
            new Branch("술사", "mystic", new Color32(0x4A, 0x4E, 0x54, 0xFF)),
        };

        /// 단계별 몬스터 이동 속도 (보드 px/s). 1–10R, 11–20R, ...
        public static readonly float[] StageSpeed = { 60, 66, 72, 80, 88, 96 };

        public static float SpeedForRound(int round) =>
            StageSpeed[Mathf.Min((Mathf.Max(round, 1) - 1) / 10, StageSpeed.Length - 1)];

        public static Vector3 ToWorld(Vector2 p) =>
            new Vector3((p.x - Width / 2) / UnitsPerWorld, (Height / 2 - p.y) / UnitsPerWorld, 0);

        /// 아래(보드 y가 큰 것)가 앞에 그려지도록 하는 정렬 순서.
        public static int SortOrder(float boardY) => Mathf.RoundToInt(boardY * 10);
    }

    public readonly struct Branch
    {
        public readonly string Name;
        public readonly string Key; // 그림 파일 이름에 쓰는 영문 키
        public readonly Color Color;

        public Branch(string name, string key, Color color)
        {
            Name = name; Key = key; Color = color;
        }
    }

    /// <summary>세로 맵 배치: 오른쪽 아래 동굴 → 3층 구불길 → 맨 위 궁. 배치 칸 25개.</summary>
    public static class MapData
    {
        public const float RoadWidth = 60;

        /// 몬스터가 걷는 길 중심선 (동굴 입구 → 궁 문). 도트 동굴 입구(512)에서 나오게 옮김.
        public static readonly Vector2[] Path =
        {
            new Vector2(512, 792),
            new Vector2(66, 792),
            new Vector2(66, 660),
            new Vector2(519, 660),
            new Vector2(519, 459),
            new Vector2(66, 459),
            new Vector2(66, 258),
            new Vector2(292.5f, 258),
            new Vector2(292.5f, 232),
        };

        public const float Tile = 63;
        static readonly float[] Cols = { 154.5f, 223.5f, 292.5f, 361.5f, 430.5f };
        static readonly float[] Rows = { 726, 594, 525, 393, 324 }; // 1층, 2층(아래·위), 3층(아래·위)

        /// 칸 가운데 목록. 앞(동굴 가까운 1층)부터.
        public static readonly List<Vector2> Tiles = BuildTiles();

        static List<Vector2> BuildTiles()
        {
            var list = new List<Vector2>();
            foreach (var y in Rows)
                foreach (var x in Cols)
                    list.Add(new Vector2(x, y));
            return list;
        }

        /// 칸 위에 선 유닛의 발 위치 (칸 가운데보다 살짝 아래).
        public static Vector2 FootOf(int tileIndex) => Tiles[tileIndex] + new Vector2(0, 14);
    }

    /// <summary>몬스터 이동 경로: 꺾은선을 길이로 따라간다.</summary>
    public class RoadTrack
    {
        readonly Vector2[] pts;
        readonly float[] acc;

        public RoadTrack(Vector2[] points)
        {
            pts = points;
            acc = new float[pts.Length];
            for (int i = 1; i < pts.Length; i++) acc[i] = acc[i - 1] + Vector2.Distance(pts[i], pts[i - 1]);
        }

        public RoadTrack() : this(MapData.Path) { }

        public float Length => acc[acc.Length - 1];

        int Seg(float s)
        {
            int lo = 0, hi = acc.Length - 1;
            while (hi - lo > 1)
            {
                int mid = (lo + hi) >> 1;
                if (acc[mid] <= s) lo = mid; else hi = mid;
            }
            return lo;
        }

        public Vector2 PositionAt(float s)
        {
            s = Mathf.Clamp(s, 0, Length);
            int i = Seg(s);
            float len = acc[i + 1] - acc[i];
            float t = len == 0 ? 0 : (s - acc[i]) / len;
            return Vector2.Lerp(pts[i], pts[i + 1], t);
        }

        public Vector2 DirectionAt(float s)
        {
            s = Mathf.Clamp(s, 0, Length);
            int i = Seg(s);
            var d = pts[i + 1] - pts[i];
            return d.sqrMagnitude == 0 ? Vector2.right : d.normalized;
        }
    }
}
