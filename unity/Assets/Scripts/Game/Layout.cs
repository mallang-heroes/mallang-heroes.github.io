using System;
using System.Collections.Generic;
using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// Resources/Art/Map/layout.json (art/tools/unity/sync_art.py가 만듦): 궁·동굴 그림 자리, 동굴 프레임, 슬라임 발 위치.
    /// </summary>
    [Serializable]
    public class Layout
    {
        public float boardW, boardH, tile;
        public XY[] tiles;
        public RectData palace, cave;
        public XY caveMouth;
        public FrameData[] caveFrames;
        public int caveFrameMs;
        public Foot[] feet;
        public Foot[] feetV2;

        [Serializable] public class XY { public float x, y; }
        [Serializable] public class RectData { public float x, y, w, h; }
        [Serializable] public class FrameData { public int x, y, w, h; }
        [Serializable] public class Foot { public string name; public float x, y; }

        static Layout cached;
        Dictionary<string, Vector2> footMap, footMapV2;

        public static Layout Load()
        {
            if (cached != null) return cached;
            var text = Resources.Load<TextAsset>("Art/Map/layout");
            cached = JsonUtility.FromJson<Layout>(text.text);
            return cached;
        }

        /// 큰 새 슬라임(UnitsV2) 발 위치. 없으면 null.
        public Vector2? FootOfV2(string spriteName)
        {
            if (footMapV2 == null)
            {
                footMapV2 = new Dictionary<string, Vector2>();
                if (feetV2 != null) foreach (var f in feetV2) footMapV2[f.name] = new Vector2(f.x, f.y);
            }
            return footMapV2.TryGetValue(spriteName, out var v) ? v : (Vector2?)null;
        }

        /// 슬라임 그림의 발 위치 (도트, 그림 왼쪽 위 기준).
        public Vector2 FootOf(string spriteName)
        {
            if (footMap == null)
            {
                footMap = new Dictionary<string, Vector2>();
                foreach (var f in feet) footMap[f.name] = new Vector2(f.x, f.y);
            }
            return footMap.TryGetValue(spriteName, out var v) ? v : Vector2.zero;
        }
    }
}
