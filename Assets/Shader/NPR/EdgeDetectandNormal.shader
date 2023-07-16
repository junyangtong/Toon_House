Shader "Unlit/EdgeDetectandNormal"
{
    Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_DetailTex("Outkine Mask", 2D) = "white" {}
		_EdgeOnly ("Edge Only", Float) = 1.0
		_EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
		_BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
		_SampleDistance ("Sample Distance", Float) = 1.0
		_Sensitivity ("Sensitivity", Vector) = (1, 1, 1, 1)
		_Saturation("_Saturation", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
		sampler2D _DetailTex;
		half4 _MainTex_TexelSize;
		fixed _EdgeOnly;
		fixed4 _EdgeColor;
		fixed4 _BackgroundColor;
		float _SampleDistance;
		half4 _Sensitivity;
		float  _Saturation;
		
		sampler2D _CameraDepthNormalsTexture;//声明获取深度+法线纹理
		
		struct v2f {
			float4 pos : SV_POSITION;
			half2 uv[5]: TEXCOORD0;
		};
	
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			half2 uv = v.texcoord;
			o.uv[0] = uv;
			
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				uv.y = 1 - uv.y;
			#endif
			
			o.uv[1] = uv + _MainTex_TexelSize.xy * half2(1,1) * _SampleDistance;
			o.uv[2] = uv + _MainTex_TexelSize.xy * half2(-1,-1) * _SampleDistance;
			o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1,1) * _SampleDistance;
			o.uv[4] = uv + _MainTex_TexelSize.xy * half2(1,-1) * _SampleDistance;
		
			return o;
		}
		
		half CheckSame(half4 center, half4 sample) {
			half2 centerNormal = center.xy;
			float centerDepth = DecodeFloatRG(center.zw);//Decode函数是把四个RGBA的值存进float类型中
			half2 sampleNormal = sample.xy;
			float sampleDepth = DecodeFloatRG(sample.zw);
			
			// 法线检测
			half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x;
			int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1;
			// 深度检测
			float diffDepth = abs(centerDepth - sampleDepth) * _Sensitivity.y;

			int isSameDepth = diffDepth < 0.1 * centerDepth;
			
			return isSameNormal * isSameDepth ? 1.0 : 0.0;//x?y:z 表示如果表达式x为true，则返回y，否则返回z；
		}
		
		fixed4 fragRobertsCrossDepthAndNormal(v2f i) : SV_Target {
			half4 sample1 = tex2D(_CameraDepthNormalsTexture, i.uv[1]);
			half4 sample2 = tex2D(_CameraDepthNormalsTexture, i.uv[2]);
			half4 sample3 = tex2D(_CameraDepthNormalsTexture, i.uv[3]);
			half4 sample4 = tex2D(_CameraDepthNormalsTexture, i.uv[4]);
			
			half edge = 1.0;
			
			edge *= CheckSame(sample1, sample2);
			edge *= CheckSame(sample3, sample4);
			//描边颜色计算

			    half4 var_MainCol = tex2D(_MainTex, i.uv[0]);
			    half var_DetailTex = tex2D(_DetailTex, i.uv[0]*2.0).r;
                half maxCol = max( max( var_MainCol.r, var_MainCol.g ), var_MainCol.b );
                half4 newMapColor = var_MainCol;
                maxCol -= ( 1.0 / 255.0 );
                half3 lerpVals = saturate( ( newMapColor.rgb - float3( maxCol, maxCol, maxCol ) ) * 255.0 );
                newMapColor.rgb = lerp( 0.6 * newMapColor.rgb, newMapColor.rgb, lerpVals );
                half4 edgecol =  0.6 * newMapColor * var_MainCol * _EdgeColor * var_DetailTex;
				edgecol = lerp(edgecol,var_MainCol,var_DetailTex);
				
				fixed gray = 0.2125 * var_MainCol.r + 0.7154 * var_MainCol.g + 0.0721 * var_MainCol.b;
				fixed4 grayColor = fixed4(gray,gray, gray,gray);
				var_MainCol = lerp(grayColor, var_MainCol,_Saturation);
			fixed4 withEdgeColor = lerp(edgecol, var_MainCol, edge);
			fixed4 onlyEdgeColor = lerp(edgecol, _BackgroundColor, edge);
			
			return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
			//return var_DetailTex;
		}
		
		ENDCG
		
		Pass { 
			ZTest Always Cull Off ZWrite Off
			
			CGPROGRAM      
			
			#pragma vertex vert  
			#pragma fragment fragRobertsCrossDepthAndNormal
			
			ENDCG  
		}
	} 
	FallBack Off
}