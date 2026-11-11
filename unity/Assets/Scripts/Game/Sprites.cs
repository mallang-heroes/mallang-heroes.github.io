using System.Collections.Generic;
using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// Resources/Art 그림을 스프라이트로 만든다. 크기는 모두 보드 좌표 기준:
    /// 맵 그림은 @2x(보드 1 = 2px), 도트 슬라임은 1도트 = 보드 2 (그림은 1도트 = 4px로 키워 둠 → 이것도 보드 1 = 2px).
    /// 피벗은 발(바닥) 자리라서, 스프라이트 위치 = 발 위치.
    /// </summary>
    public static class Sprites
    {
        public const float MapPxPerBoard = 2f;
        public const float BoardPerDot = 2f;
        public const int UnitPxPerDot = 4; // sync_art.py UNIT_PX와 같아야 함

        /// 큰 새 슬라임(UnitsV2): 몸 폭 20~28도트로 그린 것. 1도트 = 보드 1.5 = 그림 3px.
        public const float BoardPerDotV2 = 1.5f;
        public const int Unit2PxPerDot = 3; // sync_art.py UNIT2_PX와 같아야 함

        /// 맵에 맞춰 다시 뽑은 기본 슬라임(base-*): 몸 폭 23~48도트로 잘게 그려져 있어 1도트 = 보드 1.125.
        public const float BoardPerDotBase = 1.125f;

        /// 미리보기 그림 고르기 (Space로 돌아감): 옛 그림 → 큰 새 그림(V2) → 맵에 맞춘 기본 슬라임
        public enum Look { V1, V2, Base }
        public static Look Mode = Look.Base;
        public static bool UseV2 => Mode == Look.V2;

        static readonly Dictionary<string, Sprite> cache = new Dictionary<string, Sprite>();

        static Texture2D Tex(string path)
        {
            var t = Resources.Load<Texture2D>(path);
            if (t == null) { Debug.LogError($"그림 없음: Resources/{path}"); return null; }
            t.wrapMode = TextureWrapMode.Clamp;
            return t;
        }

        static float Ppu(float pxPerBoard) => pxPerBoard * Board.UnitsPerWorld;

        /// 맵 그림(@2x). pivot은 0~1 (왼쪽 아래 기준).
        public static Sprite Map(string name, Vector2 pivot)
        {
            string key = $"map:{name}:{pivot}";
            if (cache.TryGetValue(key, out var s)) return s;
            var t = Tex($"Art/Map/{name}");
            s = Sprite.Create(t, new Rect(0, 0, t.width, t.height), pivot, Ppu(MapPxPerBoard), 0, SpriteMeshType.FullRect);
            s.name = name;
            return cache[key] = s;
        }

        /// 동굴 반짝임 프레임 (시트에서 잘라냄). 피벗 = 입구 바닥(cave-glow.json의 anchor).
        public static Sprite[] CaveFrames(Layout layout, Vector2 anchorTopLeft)
        {
            var t = Tex("Art/Map/cave-glow");
            var list = new Sprite[layout.caveFrames.Length];
            for (int i = 0; i < list.Length; i++)
            {
                var f = layout.caveFrames[i];
                // 시트는 위에서부터 y, 유니티 텍스처는 아래에서부터
                var rect = new Rect(f.x, t.height - f.y - f.h, f.w, f.h);
                var pivot = new Vector2(anchorTopLeft.x, 1 - anchorTopLeft.y);
                list[i] = Sprite.Create(t, rect, pivot, Ppu(MapPxPerBoard), 0, SpriteMeshType.FullRect);
                list[i].name = $"cave-{i}";
            }
            return list;
        }

        /// 도트 슬라임 (예: "spear-jangsu"). 피벗 = 발. UseV2면 큰 새 그림이 있을 때 그것을 쓴다.
        public static Sprite Unit(string name)
        {
            if (Mode == Look.Base)
            {
                int dash = name.IndexOf('-');
                var b = UnitV2("base" + name.Substring(dash), BoardPerDotBase);
                if (b != null) return b;
            }
            if (UseV2)
            {
                var v2 = UnitV2(name);
                if (v2 != null) return v2;
            }
            return UnitV1(name);
        }

        static Sprite UnitV2(string name, float boardPerDot = BoardPerDotV2)
        {
            string key = $"unit2:{name}";
            if (cache.TryGetValue(key, out var s)) return s;
            var footDots = Layout.Load().FootOfV2(name);
            if (footDots == null) return null;
            var t = Resources.Load<Texture2D>($"Art/UnitsV2/{name}");
            if (t == null) return null;
            var foot = footDots.Value * Unit2PxPerDot;
            var pivot = new Vector2(foot.x / t.width, 1 - foot.y / t.height);
            s = Sprite.Create(t, new Rect(0, 0, t.width, t.height), pivot, Ppu(Unit2PxPerDot / boardPerDot), 0, SpriteMeshType.FullRect);
            s.name = name;
            return cache[key] = s;
        }

        static Sprite UnitV1(string name)
        {
            string key = $"unit:{name}";
            if (cache.TryGetValue(key, out var s)) return s;
            var t = Tex($"Art/Units/{name}");
            if (t == null) return null;
            var foot = Layout.Load().FootOf(name) * UnitPxPerDot; // 도트 → px
            var pivot = new Vector2(foot.x / t.width, 1 - foot.y / t.height);
            s = Sprite.Create(t, new Rect(0, 0, t.width, t.height), pivot, Ppu(UnitPxPerDot / BoardPerDot), 0, SpriteMeshType.FullRect);
            s.name = name;
            return cache[key] = s;
        }

        /// 단색 동그라미 (몬스터 자리표시용).
        public static Sprite Circle(int sizePx = 16)
        {
            string key = $"circle:{sizePx}";
            if (cache.TryGetValue(key, out var s)) return s;
            var t = new Texture2D(sizePx, sizePx, TextureFormat.RGBA32, false) { filterMode = FilterMode.Point };
            float r = sizePx / 2f;
            for (int y = 0; y < sizePx; y++)
                for (int x = 0; x < sizePx; x++)
                {
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(r, r));
                    t.SetPixel(x, y, d <= r - 1 ? Color.white : d <= r ? new Color(0.16f, 0.13f, 0.11f) : Color.clear);
                }
            t.Apply();
            s = Sprite.Create(t, new Rect(0, 0, sizePx, sizePx), new Vector2(0.5f, 0f), Ppu(1f / BoardPerDot));
            return cache[key] = s;
        }
    }
}
