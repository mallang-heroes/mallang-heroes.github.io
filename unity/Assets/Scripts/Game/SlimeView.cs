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
        public int TileIndex { get; private set; }
        Vector2 poseOff;          // 공격 모션이 주는 위치(보드)·크기
        Vector2 poseScale = Vector2.one;

        /// 공격 모션에서 매 프레임 넣는 자세 (보드 좌표 이동, 가로·세로 배율). 발을 기준으로 늘었다 줄었다 한다.
        public void SetPose(Vector2 boardOffset, Vector2 scale) { poseOff = boardOffset; poseScale = scale; }
        float phase;
        Vector3 basePos;
        SpriteRenderer sr;

        /// 그림을 다시 고른다 (옛/새 그림 바꿀 때).
        public void Refresh() => sr.sprite = Sprites.Unit($"{BranchKey}-{Rules.TierKeys[Tier]}");

        public static SlimeView Create(Transform parent, string branchKey, int tier, int tileIndex)
        {
            var go = new GameObject($"{branchKey}-{Rules.TierKeys[tier]}");
            go.transform.SetParent(parent, false);
            var foot = MapData.FootOf(tileIndex);
            go.transform.localPosition = Board.ToWorld(foot);
            var v = go.AddComponent<SlimeView>();
            v.BranchKey = branchKey;
            v.Tier = tier;
            v.TileIndex = tileIndex;
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
            bool attacking = poseScale != Vector2.one || poseOff != Vector2.zero;
            bool up = !attacking && Mathf.Repeat(Time.time / HopPeriod + phase, 1f) < 0.5f;
            float dy = up ? Sprites.BoardPerDot / Board.UnitsPerWorld : 0f; // 1도트
            var off = new Vector3(poseOff.x, -poseOff.y, 0) / Board.UnitsPerWorld;  // 보드 y는 아래로
            transform.localPosition = basePos + off + new Vector3(0, dy, 0);
            transform.localScale = new Vector3(poseScale.x, poseScale.y, 1);   // 피벗이 발이라 발은 땅에 붙은 채로
        }
    }
}
