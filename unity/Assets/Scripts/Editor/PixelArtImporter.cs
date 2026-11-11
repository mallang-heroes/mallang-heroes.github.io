using UnityEditor;
using UnityEngine;

namespace Mallang.EditorTools
{
    /// <summary>
    /// Resources/Art 아래 그림 가져오기 설정.
    /// 그림은 폰 화면(1170 폭)에서 1:1이 되게 크게 만들어 두고(맵 @2x, 도트 유닛 1도트 = 4px),
    /// 그보다 작은 화면(에디터 Game 창 등)에서는 부드럽게 줄인다(Bilinear + 밉맵).
    /// Point로 두면 1도트가 1.6px처럼 소수 배율일 때 도트 굵기가 들쭉날쭉해져 그림이 깨져 보인다.
    /// 스프라이트는 게임 코드(Sprites.cs)가 Texture2D에서 직접 만든다.
    /// </summary>
    public class PixelArtImporter : AssetPostprocessor
    {
        // 설정을 바꾸면 이 숫자를 올린다 → 유니티가 그림을 다시 가져온다
        public override uint GetVersion() => 2;

        void OnPreprocessTexture()
        {
            if (!assetPath.Contains("/Resources/Art/")) return;
            var ti = (TextureImporter)assetImporter;
            ti.textureType = TextureImporterType.Default;
            ti.filterMode = FilterMode.Bilinear;
            ti.textureCompression = TextureImporterCompression.Uncompressed;
            ti.npotScale = TextureImporterNPOTScale.None;
            ti.mipmapEnabled = true;
            ti.mipmapFilter = TextureImporterMipFilter.KaiserFilter;
            ti.mipMapsPreserveCoverage = false;
            ti.borderMipmap = true; // 가장자리 투명 번짐 줄이기
            ti.alphaIsTransparency = true;
            ti.wrapMode = TextureWrapMode.Clamp;
            ti.maxTextureSize = 4096;
        }
    }
}
