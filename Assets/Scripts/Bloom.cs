using UnityEngine;
using System.Collections;

public class Bloom : PostEffectsBase {

	public Shader bloomShader;
	private Material bloomMaterial = null;
	public Material material {  
		get {
			bloomMaterial = CheckShaderAndCreateMaterial(bloomShader, bloomMaterial);
			return bloomMaterial;
		}  
	}

	// Blur iterations - larger number means more blur.
	[Range(0, 4)]
	public int iterations = 3;
	
	// Blur spread for each iteration - larger value means more blur
	[Range(0.2f, 3.0f)]
	public float blurSpread = 0.6f;

	[Range(1, 8)]
	public int downSample = 2;

	[Range(0.0f, 4.0f)]
	public float luminanceThreshold = 0.6f;//比高斯模糊多增加了一个高光区域阈值

	[ColorUsageAttribute(false, true)]//showAlpha 是否显示 Alpha 配置项、HDR 是否高动态范围 
	public Color BloomColor = Color.white;

	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			material.SetColor("_BloomColor", BloomColor);
			material.SetFloat("_LuminanceThreshold", luminanceThreshold);
		
			int rtW = src.width/downSample;
			int rtH = src.height/downSample;
			
			RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
			buffer0.filterMode = FilterMode.Bilinear;
			
			Graphics.Blit(src, buffer0, material, 0);//储存图像中较亮的部分pass1
			
			for (int i = 0; i < iterations; i++) {
				material.SetFloat("_BlurSize", 1.0f + i * blurSpread);
				
				RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
				
				// Render the vertical pass
				Graphics.Blit(buffer0, buffer1, material, 1);//进行模糊处理1pass2
				
				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
				buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
				
				// Render the horizontal pass
				Graphics.Blit(buffer0, buffer1, material, 2);//进行模糊处理2pass3
				
				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
			}

			material.SetTexture ("_Bloom", buffer0);  //传递bloom之后的图像
			Graphics.Blit (src, dest, material, 3);  //pass4混合bloom和原图

			RenderTexture.ReleaseTemporary(buffer0);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}