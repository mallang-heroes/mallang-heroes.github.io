using UnityEditor;
using UnityEngine;

namespace Mallang.EditorTools
{
    /// <summary>
    /// Resources/Art 아래 그림을 도트에 맞게 가져온다: 흐리게 하지 않음(Point), 압축 없음, 2의 거듭제곱으로 늘리지 않음.
    /// 스프라이트는 게임 코드(Sprites.cs)가 Texture2D에서 직접 만든다.
    /// </summary>
    public class PixelArtImporter : AssetPostprocessor
    {
        void OnPreprocessTexture()
        {
            if (!assetPath.Contains("/Resources/Art/")) return;
            var ti = (TextureImporter)assetImporter;
            ti.textureType = TextureImporterType.Default;
            ti.filterMode = FilterMode.Point;
            ti.textureCompression = TextureImporterCompression.Uncompressed;
            ti.npotScale = TextureImporterNPOTScale.None;
            ti.mipmapEnabled = false;
            ti.alphaIsTransparency = true;
            ti.wrapMode = TextureWrapMode.Clamp;
            ti.maxTextureSize = 4096;
        }
    }
}
