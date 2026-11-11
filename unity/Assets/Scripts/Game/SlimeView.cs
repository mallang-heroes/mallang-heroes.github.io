using UnityEngine;

namespace Mallang
{
    /// <summary>칸 위 도트 슬라임 하나. 발이 칸 발자리에 오고, 말랑하게 숨 쉬듯 늘었다 줄었다 한다.</summary>
    public class SlimeView : MonoBehaviour
    {
        public string BranchKey { get; private set; }
        public int Tier { get; private set; }
        float phase;
        SpriteRenderer sr;

        public static SlimeView Create(Transform parent, string branchKey, int tier, int tileIndex)
        {
            var go = new GameObject($"{branchKey}-{Rules.TierKeys[tier]}");
            go.transform.SetParent(parent, false);
            var foot = MapData.FootOf(tileIndex);
            go.transform.localPosition = Board.ToWorld(foot);
            var v = go.AddComponent<SlimeView>();
            v.BranchKey = branchKey;
            v.Tier = tier;
            v.sr = go.AddComponent<SpriteRenderer>();
            v.sr.sprite = Sprites.Unit($"{branchKey}-{Rules.TierKeys[tier]}");
            v.sr.sortingOrder = Board.SortOrder(foot.y);
            v.phase = Random.value * Mathf.PI * 2;
            return v;
        }

        void Update()
        {
            // 도트가 깨지지 않게 아주 살짝만 (세로 ±3%)
            float k = Mathf.Sin(Time.time * 3f + phase) * 0.03f;
            transform.localScale = new Vector3(1 - k * 0.5f, 1 + k, 1);
        }
    }
}
