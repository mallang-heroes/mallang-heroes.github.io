using UnityEngine;

namespace Mallang
{
    /// <summary>세로 맵 그리기: 바닥 → 동굴(반짝임 4프레임) → 궁. 유닛·몬스터와 위아래 순서가 맞게 정렬한다.</summary>
    public class MapView : MonoBehaviour
    {
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
            frameTime += Time.deltaTime;
            if (frameTime < frameSec) return;
            frameTime -= frameSec;
            frame = (frame + 1) % caveFrames.Length;
            cave.sprite = caveFrames[frame];
        }
    }
}
