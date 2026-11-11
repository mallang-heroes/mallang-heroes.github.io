using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// 칸 위 도트 슬라임 하나. 발이 칸 발자리에 온다.
    /// 대기 움직임은 크기를 늘였다 줄이면 도트가 뭉개지므로, 0.4초마다 1도트씩 통통 뛰는 2단 움직임으로 한다.
    /// </summary>
    public class SlimeView : MonoBehaviour
    {
        public string BranchKey { get; private set; }
        public int Tier { get; private set; }
        float phase;
        Vector3 basePos;
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
            v.phase = Random.value;
            v.basePos = go.transform.localPosition;
            return v;
        }

        const float HopPeriod = 0.8f; // 한 번 뛰고 내려오는 시간

        void Update()
        {
            bool up = Mathf.Repeat(Time.time / HopPeriod + phase, 1f) < 0.5f;
            float dy = up ? Sprites.BoardPerDot / Board.UnitsPerWorld : 0f; // 1도트
            transform.localPosition = basePos + new Vector3(0, dy, 0);
        }
    }
}
