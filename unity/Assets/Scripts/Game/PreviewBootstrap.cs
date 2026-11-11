using UnityEngine;

namespace Mallang
{
    /// <summary>
    /// 1단계 확인용: 빈 씬에서 ▶ 누르면 자동으로 세로 맵 + 도트 슬라임 + 길 따라 걷는 자리표시 몬스터를 띄운다.
    /// (씬 파일 없이 동작. 본 게임 로직을 옮기면 GameBootstrap으로 바꾼다.)
    /// </summary>
    public class PreviewBootstrap : MonoBehaviour
    {
        // 칸 번호(앞 1층부터 0~24) → (병과 키, 등급)
        static readonly (int tile, string branch, int tier)[] Plan =
        {
            (0, "spear", 0), (1, "archer", 0), (2, "gunner", 1), (3, "spear", 1), (4, "archer", 2),
            (5, "gunner", 0), (6, "spear", 2), (8, "archer", 1), (9, "gunner", 2),
            (10, "spear", 0), (12, "archer", 3), (14, "gunner", 0),
            (15, "archer", 0), (16, "spear", 3), (18, "gunner", 3), (19, "spear", 1),
            (20, "gunner", 1), (21, "archer", 1), (23, "spear", 2), (24, "archer", 0),
        };

        /// 미리보기에서 몬스터를 빨리 보내 공격을 빨리 확인 (게임 수치는 그대로)
        const float PreviewMobSpeed = 2f;

        RoadTrack track;
        float spawnTimer;
        int spawned;
        Camera cam;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (FindAnyObjectByType<PreviewBootstrap>() != null) return;
            new GameObject("Mallang Preview").AddComponent<PreviewBootstrap>();
        }

        void Start()
        {
            Application.targetFrameRate = 60;
            cam = Camera.main;
            if (cam == null)
            {
                var go = new GameObject("Main Camera") { tag = "MainCamera" };
                cam = go.AddComponent<Camera>();
            }
            cam.orthographic = true;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color32(0x2A, 0x21, 0x1C, 0xFF);
            cam.transform.position = new Vector3(0, 0, -10);
            FitCamera();

            MapView.Create(transform);
            var units = new GameObject("Units").transform;
            units.SetParent(transform, false);
            foreach (var p in Plan)
            {
                var v = SlimeView.Create(units, p.branch, p.tier, p.tile);
                AttackMotion.Attach(v, BranchName(p.branch));
            }

            track = new RoadTrack();
        }

        static string BranchName(string key)
        {
            foreach (var b in Board.Branches) if (b.Key == key) return b.Name;
            return "창병";
        }

        void FitCamera()
        {
            // 보드 전체가 화면 폭·높이 안에 들어오게
            float halfH = Board.Height / 2 / Board.UnitsPerWorld;
            float halfW = Board.Width / 2 / Board.UnitsPerWorld;
            cam.orthographicSize = Mathf.Max(halfH, halfW / cam.aspect);
        }

        void Update()
        {
            FitCamera();
            // S: 공격 모션 느리게(1/4) ↔ 보통
            if (Input.GetKeyDown(KeyCode.S))
            {
                Time.timeScale = Time.timeScale < 1f ? 1f : 0.25f;
            }
            // Space: 카툰 → 옛 그림 → 큰 새 그림(V2) → 도트 기본 슬라임 순서로 바꿔 보기
            if (Input.GetKeyDown(KeyCode.Space))
            {
                Sprites.Mode = (Sprites.Look)(((int)Sprites.Mode + 1) % 4);
                Debug.Log($"슬라임 그림: {Sprites.Mode}");
                foreach (var v in FindObjectsByType<SlimeView>(FindObjectsSortMode.None)) v.Refresh();
            }
            spawnTimer += Time.deltaTime;
            if (spawnTimer < Rules.SpawnGap) return;
            spawnTimer -= Rules.SpawnGap;
            float lane = (spawned++ % 2 == 0 ? 1 : -1) * Rules.LaneOffset;
            var color = Color.Lerp(new Color(0.55f, 0.36f, 0.25f), new Color(0.85f, 0.85f, 0.9f), (spawned % 10) / 10f);
            MobPlaceholder.Create(transform, track, Board.SpeedForRound(1) * PreviewMobSpeed, lane, color);
        }
    }
}
