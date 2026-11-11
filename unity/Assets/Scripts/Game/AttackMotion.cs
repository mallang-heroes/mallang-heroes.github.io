using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// 기본 슬라임 공격 모션 (미리보기): 사거리 안 가장 앞선 몬스터를 향해
    ///   ① 움츠림(0.07초, 납작) → ② 튀어나가며 찌르기(0.08초, 길쭉 + 목표 쪽으로 몇 도트) → ③ 제자리로 말랑 복귀(0.18초)
    /// 찌르는 순간 병과별 타격 효과(창: 찌르기 선)와 몬스터 번쩍·밀림.
    /// 그림 한 장으로 하는 코드 모션이라 병과·등급 그림이 바뀌어도 그대로 쓴다. (위인은 파츠 리깅 예정)
    /// 무기는 오른손 고정 → 좌우 뒤집지 않는다.
    /// </summary>
    public class AttackMotion : MonoBehaviour
    {
        SlimeView slime;
        float cooldown;
        float t = -1;           // 모션 진행 시간 (-1 = 대기)
        Vector2 dir;            // 목표 방향 (보드)
        MobPlaceholder target;
        bool struck;
        float range, interval, lunge;

        const float Wind = 0.07f, Strike = 0.08f, Recover = 0.18f;

        public static AttackMotion Attach(SlimeView s, string branchName)
        {
            var a = s.gameObject.AddComponent<AttackMotion>();
            a.slime = s;
            a.range = Rules.RangeRadius(branchName);
            a.interval = 1f / Rules.Stats[branchName].Speed;
            a.lunge = 6f + s.Tier * 2f;     // 보드: 등급이 높을수록 크게 튀어나감
            a.cooldown = Random.value * a.interval;
            return a;
        }

        Vector2 Foot => MapData.FootOf(slime.TileIndex);

        void Update()
        {
            float dt = Time.deltaTime;   // 느리게 보기는 Time.timeScale (S 키)
            if (t < 0)
            {
                cooldown -= dt;
                if (cooldown > 0) return;
                target = FindTarget();
                if (target == null) { cooldown = 0.1f; return; }
                dir = (target.BoardPos - Foot).normalized;
                t = 0; struck = false;
                cooldown = interval;
            }
            t += dt;

            float sx = 1, sy = 1; Vector2 off = Vector2.zero;
            if (t < Wind)
            {   // 움츠림: 납작하게, 반대쪽으로 살짝
                float k = Ease(t / Wind);
                sx = 1 + 0.18f * k; sy = 1 - 0.2f * k;
                off = -dir * 2f * k;
            }
            else if (t < Wind + Strike)
            {   // 찌르기: 길쭉하게 튀어나감
                float k = Ease((t - Wind) / Strike);
                sx = 1.18f - 0.3f * k; sy = 0.8f + 0.35f * k;
                off = Vector2.Lerp(-dir * 2f, dir * lunge, k);
                if (!struck && k > 0.6f) { struck = true; Impact(); }
            }
            else if (t < Wind + Strike + Recover)
            {   // 복귀: 말랑하게 출렁이며 제자리
                float k = (t - Wind - Strike) / Recover;
                float wob = Mathf.Sin(k * Mathf.PI * 2.5f) * (1 - k);
                sx = 1 - 0.1f * wob; sy = 1 + 0.1f * wob;
                off = dir * lunge * (1 - Ease(k));
            }
            else { t = -1; }

            slime.SetPose(off, new Vector2(sx, sy));
        }

        static float Ease(float x) => 1 - (1 - x) * (1 - x);

        MobPlaceholder FindTarget()
        {
            MobPlaceholder best = null; float bestD = range;
            var foot = Foot;
            foreach (var m in MobPlaceholder.All)
            {
                float d = Vector2.Distance(m.BoardPos, foot);
                if (d <= bestD) { bestD = d; best = m; }
            }
            return best;
        }

        void Impact()
        {
            if (target == null) return;
            target.Hit(4f + slime.Tier);
            HitEffect.Thrust(transform.parent, Foot + new Vector2(0, -14) + dir * (lunge + 10), target.BoardPos + new Vector2(0, -6), slime.Tier);
        }
    }

    /// <summary>타격 효과: 창 찌르기 선 (하얗게 번쩍였다 사라짐).</summary>
    public class HitEffect : MonoBehaviour
    {
        SpriteRenderer sr;
        float life, max;

        static Sprite pixel;

        public static void Thrust(Transform parent, Vector2 from, Vector2 to, int tier)
        {
            if (pixel == null)
            {
                var tex = new Texture2D(1, 1) { filterMode = FilterMode.Point };
                tex.SetPixel(0, 0, Color.white); tex.Apply();
                pixel = Sprite.Create(tex, new Rect(0, 0, 1, 1), new Vector2(0, 0.5f), 1);
            }
            var go = new GameObject("Thrust");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = Board.ToWorld(from);
            var d = to - from;
            float ang = Mathf.Atan2(-d.y, d.x) * Mathf.Rad2Deg;   // 보드 y는 아래로
            go.transform.localRotation = Quaternion.Euler(0, 0, ang);
            float len = Mathf.Max(8, d.magnitude) / Board.UnitsPerWorld;
            float thick = (2f + tier) / Board.UnitsPerWorld;
            go.transform.localScale = new Vector3(len, thick, 1);
            var e = go.AddComponent<HitEffect>();
            e.sr = go.AddComponent<SpriteRenderer>();
            e.sr.sprite = pixel;
            e.sr.color = new Color(1f, 0.97f, 0.85f, 0.95f);
            e.sr.sortingOrder = short.MaxValue - 10;
            e.life = e.max = 0.12f;
        }

        void Update()
        {
            life -= Time.deltaTime;
            if (life <= 0) { Destroy(gameObject); return; }
            var c = sr.color; c.a = life / max; sr.color = c;
            var s = transform.localScale; s.y *= 0.9f; transform.localScale = s;
        }
    }
}
