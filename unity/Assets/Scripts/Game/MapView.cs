using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// 세로 맵 그리기. 카툰 맵(2026-11-11 확정): 바닥 한 장(궁·동굴 포함) + 몬스터를 덮는 동굴 바위.
    /// 옛 도트 맵(Cartoon = false): 바닥 → 동굴(반짝임 4프레임) → 궁.
    /// </summary>
    public class MapView : MonoBehaviour
    {
        public static bool Cartoon = true;

        SpriteRenderer cave;
        Sprite[] caveFrames;
        float frameTime;
        int frame;
        float frameSec;

        public static MapView Create(Transform parent)
        {
            var go = new GameObject("Map");
            go.transform.SetParent(parent, false);
            var v = go.AddComponent<MapView>();
            v.Build();
            return v;
        }

        void Build()
        {
            var layout = Layout.Load();
            if (Cartoon && Resources.Load<Texture2D>("Art/Map/ground-cartoon") != null)
            {
                var g = MakeRenderer("Ground", Sprites.Map("ground-cartoon", new Vector2(0, 1)), Vector2.zero);
                g.sortingOrder = short.MinValue;
                g.transform.localPosition += new Vector3(0, 0, 1);
                // 동굴 바위: 왼쪽 위를 caveFront에, 길 위 몬스터보다 앞 (동굴 안에서 걸어 나오게)
                var cf = layout.caveFront;
                var front = MakeRenderer("CaveFront", Sprites.Map("cave-front", new Vector2(0, 1)), new Vector2(cf.x, cf.y));
                front.sortingOrder = Board.SortOrder(Board.Height) + 1;
                return;
            }

            // 바닥: 왼쪽 위를 보드 (0,0)에
            var ground = MakeRenderer("Ground", Sprites.Map("ground", new Vector2(0, 1)), Vector2.zero);
            ground.sortingOrder = short.MinValue; // 정렬 순서는 -32768~32767 (넘으면 값이 돌아서 맨 앞에 그려짐)
            ground.transform.localPosition += new Vector3(0, 0, 1); // 카메라에서 한 칸 더 멀리 (확실히 맨 뒤)

            // 궁: 왼쪽 아래를 rect 아래 끝에
            var pr = layout.palace;
            var palace = MakeRenderer("Palace", Sprites.Map("palace", Vector2.zero), new Vector2(pr.x, pr.y + pr.h));
            palace.sortingOrder = Board.SortOrder(pr.y + pr.h);

            // 동굴: 입구 바닥 가운데를 caveMouth에
            caveFrames = Sprites.CaveFrames(layout, new Vector2(0.2857f, 0.9733f));
            var mouth = new Vector2(layout.caveMouth.x, layout.caveMouth.y);
            cave = MakeRenderer("Cave", caveFrames[0], mouth);
            cave.sortingOrder = Board.SortOrder(mouth.y);
            frameSec = layout.caveFrameMs / 1000f;
        }

        SpriteRenderer MakeRenderer(string name, Sprite sprite, Vector2 boardPos)
        {
            var go = new GameObject(name);
            go.transform.SetParent(transform, false);
            go.transform.localPosition = Board.ToWorld(boardPos);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = sprite;
            return sr;
        }

        void Update()
        {
            if (cave == null) return;
            frameTime += Time.deltaTime;
            if (frameTime < frameSec) return;
            frameTime -= frameSec;
            frame = (frame + 1) % caveFrames.Length;
            cave.sprite = caveFrames[frame];
        }
    }
}
