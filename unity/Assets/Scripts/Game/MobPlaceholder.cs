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
        Color baseColor;
        float flash;      // 맞았을 때 하얗게 번쩍 (초)
        float knock;      // 맞았을 때 뒤로 밀림 (보드)

        /// 지금 맵에 있는 몬스터 (공격 대상 찾기용)
        public static readonly System.Collections.Generic.List<MobPlaceholder> All = new System.Collections.Generic.List<MobPlaceholder>();

        /// 보드 좌표 위치 (발)
        public Vector2 BoardPos { get; private set; }

        /// 맞음: 잠깐 하얗게 + 살짝 뒤로 밀림
        public void Hit(float push = 4f)
        {
            flash = 0.1f;
            knock = Mathf.Max(knock, push);
        }

        void OnEnable() => All.Add(this);
        void OnDisable() => All.Remove(this);

        public static MobPlaceholder Create(Transform parent, RoadTrack track, float speed, float lane, Color color)
        {
            var go = new GameObject("Mob");
            go.transform.SetParent(parent, false);
            var m = go.AddComponent<MobPlaceholder>();
            m.track = track; m.speed = speed; m.lane = lane;
            m.sr = go.AddComponent<SpriteRenderer>();
            m.sr.sprite = Sprites.Circle(14);
            m.sr.color = color;
            m.baseColor = color;
            m.Place();
            return m;
        }

        void Place()
        {
            var p = track.PositionAt(s);
            var d = track.DirectionAt(s);
            var side = new Vector2(-d.y, d.x) * lane;
            var b = p + side - d * knock;
            BoardPos = b;
            transform.localPosition = Board.ToWorld(b);
            sr.sortingOrder = Board.SortOrder(b.y);
            sr.flipX = d.x > 0;
        }

        void Update()
        {
            s += speed * Time.deltaTime;
            if (s >= track.Length) { Destroy(gameObject); return; }
            knock = Mathf.MoveTowards(knock, 0, 40f * Time.deltaTime);
            flash -= Time.deltaTime;
            sr.color = flash > 0 ? Color.white : baseColor;
            Place();
        }
    }
}
