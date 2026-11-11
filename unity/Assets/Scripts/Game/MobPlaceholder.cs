using UnityEngine;

namespace Mallang
{
    /// <summary>몬스터 그림이 나오기 전 자리표시: 동굴에서 나와 길을 따라 궁까지 걷는 동그라미.</summary>
    public class MobPlaceholder : MonoBehaviour
    {
        RoadTrack track;
        float s;
        float speed;
        float lane;
        SpriteRenderer sr;

        public static MobPlaceholder Create(Transform parent, RoadTrack track, float speed, float lane, Color color)
        {
            var go = new GameObject("Mob");
            go.transform.SetParent(parent, false);
            var m = go.AddComponent<MobPlaceholder>();
            m.track = track; m.speed = speed; m.lane = lane;
            m.sr = go.AddComponent<SpriteRenderer>();
            m.sr.sprite = Sprites.Circle(14);
            m.sr.color = color;
            m.Place();
            return m;
        }

        void Place()
        {
            var p = track.PositionAt(s);
            var d = track.DirectionAt(s);
            var side = new Vector2(-d.y, d.x) * lane;
            var b = p + side;
            transform.localPosition = Board.ToWorld(b);
            sr.sortingOrder = Board.SortOrder(b.y);
            sr.flipX = d.x > 0;
        }

        void Update()
        {
            s += speed * Time.deltaTime;
            if (s >= track.Length) { Destroy(gameObject); return; }
            Place();
        }
    }
}
