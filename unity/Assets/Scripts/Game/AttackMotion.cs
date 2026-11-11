using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// 공격 모션 (미리보기).
    /// 무기 파츠가 있으면(창병 등): 쥔 손은 그림 그대로 두고, 창끝을 목표로 재빨리 돌려 겨누며 뒤로 당김
    ///   → 창끝이 몬스터에 닿도록 창 방향으로 쭉 찔러 넣기(0.06초) → 잠깐 멈춤 → 빼서 다시 세워 들기(0.18초).
    ///   몸은 찌르는 순간 목표 쪽으로 살짝 기울며 늘어난다.
    /// 무기 파츠가 없으면(기본 슬라임): 사거리 안 가장 앞선 몬스터를 향해
    ///   ① 움츠림(0.07초, 납작) → ② 튀어나가며 찌르기(0.08초, 길쭉 + 목표 쪽으로 몇 도트) → ③ 제자리로 말랑 복귀(0.18초)
    /// 찌르는 순간 병과별 타격 효과(창: 찌르기 선)와 몬스터 번쩍·밀림.
    /// 그림 한 장으로 하는 코드 모션이라 병과·등급 그림이 바뀌어도 그대로 쓴다. (위인은 파츠 리깅 예정)
    /// 무기는 오른손 고정 → 좌우 뒤집지 않는다. 카툰은 찌를 때 손이 창을 쥔 채 따라 나가고 몸에서 손까지 젤리 팔이 늘어난다 (SlimeView.UpdateArm).
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
        const float Aim = 0.09f, Stab = 0.045f, Hold = 0.08f, Back = 0.16f;   // 무기 찌르기: 크게 당겼다가 순식간에 찌름
        float aimAngle, reachNow;
        Vector2 aimDir;

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
                if (slime.HasWeapon)
                {   // 그림에 그려진 손 그대로 쥔 채, 창끝이 목표를 향하게 (창끝 위 = 0도, 시계 반대가 +)
                    var hand = Foot + slime.GripFromFoot;
                    var to = target.BoardPos + new Vector2(0, -6) - hand;
                    aimDir = to.normalized;
                    aimAngle = Mathf.Atan2(-aimDir.y, aimDir.x) * Mathf.Rad2Deg - 90f;
                    if (aimAngle < -180) aimAngle += 360;
                    // 창끝이 몬스터에 닿을 만큼만 내지름
                    reachNow = Mathf.Clamp(to.magnitude - slime.TipLen + 2f, 4f, 32f);   // 창끝이 몬스터 속으로 살짝 들어가게
                }
                t = 0; struck = false;
                cooldown = interval;
            }
            t += dt;
            if (slime.HasWeapon) { WeaponStab(); return; }

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

        void WeaponStab()
        {
            float reach = reachNow;   // 찔러 넣는 거리 (보드): 창끝이 몬스터에 닿을 만큼
            float ang, push; float sx = 1, sy = 1; Vector2 lean = Vector2.zero;
            if (t < Aim)
            {   // 겨누기: 창을 목표 쪽으로 돌리며 살짝 뒤로 당김, 몸은 움츠림
                float k = Ease(t / Aim);
                ang = aimAngle * k; push = -10f * k;   // 크게 뒤로 당김 (예비 동작)
                sx = 1 + 0.06f * k; sy = 1 - 0.06f * k;
            }
            else if (t < Aim + Stab)
            {   // 찌르기: 쭉 뻗음, 몸도 목표 쪽으로 기울며 늘어남
                float k = Ease((t - Aim) / Stab);
                ang = aimAngle; push = Mathf.Lerp(-10f, reach + 6f, k);   // 목표보다 조금 더 깊이 (오버슈트)
                sx = 1.06f - 0.12f * k; sy = 0.94f + 0.14f * k;
                lean = dir * 4f * k;
                if (!struck && k > 0.7f) { struck = true; Impact(); }
            }
            else if (t < Aim + Stab + Hold)
            {   // 찌른 채로 잠깐 멈춤 (타격감)
                float k = (t - Aim - Stab) / Hold;
                ang = aimAngle; push = reach + 6f * (1 - Ease(k)); sx = 0.94f; sy = 1.08f; lean = dir * 4f;
            }
            else if (t < Aim + Stab + Hold + Back)
            {   // 빼서 다시 세워 들기, 몸은 말랑하게 출렁
                float k = (t - Aim - Stab - Hold) / Back;
                float e = Ease(k);
                ang = aimAngle * (1 - e); push = reach * (1 - e);
                float wob = Mathf.Sin(k * Mathf.PI * 2f) * (1 - k);
                sx = 1 - 0.06f * wob; sy = 1 + 0.06f * wob; lean = dir * 4f * (1 - e);
            }
            else { t = -1; ang = 0; push = 0; }
            slime.SetWeaponPose(ang, aimDir * push);   // 창 방향으로만 밀고 당김 → 창끝이 앞장선다
            slime.SetPose(lean, new Vector2(sx, sy));
        }

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
            if (slime.HasWeapon) { HitEffect.Spark(transform.parent, target.BoardPos + new Vector2(0, -6), slime.Tier); return; }
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

        /// 찔린 자리 번쩍: 십자 모양 짧은 빛
        public static void Spark(Transform parent, Vector2 at, int tier)
        {
            float len = 10f + tier * 3f;
            Thrust(parent, at + new Vector2(-len / 2, 0), at + new Vector2(len / 2, 0), tier);
            Thrust(parent, at + new Vector2(0, -len / 2), at + new Vector2(0, len / 2), tier);
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
