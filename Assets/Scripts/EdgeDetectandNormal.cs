using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EdgeDetectandNormal : PostEffectsBase {

	public Shader edgeDetectShader;
	private Material edgeDetectMaterial = null;
	public Material material {  
		get {
			edgeDetectMaterial = CheckShaderAndCreateMaterial(edgeDetectShader, edgeDetectMaterial);
			return edgeDetectMaterial;
		}  
	}
	public Texture DetailTex;

	[Range(0.0f, 1.0f)]
	public float edgesOnly = 0.0f;

	public Color edgeColor = Color.black;

	public Color backgroundColor = Color.white;

	public float sampleDistance = 1.0f;//采样距离

	public float sensitivityDepth = 1.0f;//深度检测灵敏度

	public float sensitivityNormals = 1.0f;//法线检测灵敏度
	
	public float saturation = 1.0f;//饱和度
	
	void OnEnable() {
		GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
	}

	[ImageEffectOpaque]//只对小于2500的pass产生影响就是说不影响透明物体
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
            //赋值
			material.SetTexture("_DetailTex", DetailTex);//设置贴图
			material.SetFloat("_EdgeOnly", edgesOnly);
			material.SetColor("_EdgeColor", edgeColor);
			material.SetColor("_BackgroundColor", backgroundColor);
			material.SetFloat("_SampleDistance", sampleDistance);
			material.SetVector("_Sensitivity", new Vector4(sensitivityNormals, sensitivityDepth, 0.0f, 0.0f));
			material.SetFloat("_Saturation", saturation);
			Graphics.Blit(src, dest, material);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}