Shader "NPR" {
    Properties {
        [Header(Texture)]
        _MainCol("基本色贴图",2d) = "white"{}
        _RampTex("Ramp贴图",2d) = "white"{}
        _LightRampTex("灯光Ramp贴图",2d) = "white"{}
        [Header(Lighting)]
        _AmbCol("环境光颜色",color) =(1.0,1.0,1.0,1.0)
        _AmbInt ("环境光强度", Range(0.01, 5)) = 1.0
        [HDR]_ShadowCol("阴影颜色",color) =(0.0,0.0,0.0,0.0)
        _LimCol1("光照贴图颜色1",color) =(0.0,0.0,0.0,0.0)
        [HDR]_LimCol2("光照贴图颜色2",color) =(0.0,0.0,0.0,0.0)
    }
    SubShader {
        Tags {
            "RenderType"="Opaque"
        }
        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            
            
            CGPROGRAM
            //投影
            #include "AutoLight.cginc"   
            #include "Lighting.cginc"
            //
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #pragma multi_compile_fwdbase_fullshadows
            #pragma target 3.0
            // LightMap打开或者关闭
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON 
            

            //获取参数
            uniform sampler2D  _MainCol;
            uniform sampler2D  _RampTex;
            uniform half4  _ShadowCol;
            uniform half4  _AmbCol;
            uniform half  _AmbInt;
            uniform half4  _LimCol1;
            uniform half4  _LimCol2;
            //输入结构
            struct VertexInput {
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half2 uv    : TEXCOORD0;
                #ifdef LIGHTMAP_ON 
                half2 uv1 : TEXCOORD1;
                #endif 

            };
            //输出结构
            struct VertexOutput {
                half4 pos            : SV_POSITION;
                half4 posWS          : TEXCOORD0;
                half3 normalDir      : TEXCOORD1;  
                LIGHTING_COORDS(2,3)
                half2 uv             : TEXCOORD4;
                #ifdef LIGHTMAP_ON 
                half2 lightmapUV     : TEXCOORD5;
                #endif 
            };
            //输出结构>>>顶点Shader>>>输出结构
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.pos = UnityObjectToClipPos( v.vertex );
                o.posWS=mul(unity_ObjectToWorld, v.vertex);
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                o.uv=v.uv;
                #ifdef LIGHTMAP_ON  
                o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                return o;
            }
            //输出结构>>>像素
            half4 frag(VertexOutput i) : COLOR {
                //准备向量
                half3 nDir = i.normalDir; 
                half3 lDir = normalize (_WorldSpaceLightPos0.xyz); 
                //准备中间数据（点积结果）
                half nDotl = dot(nDir,lDir); 
                half Lambert = max(0.0,nDotl);
                //贴图采样
                half3 var_MainCol = tex2D(_MainCol,i.uv).rgb;
                half3 var_RampTex = tex2D(_RampTex,half2(Lambert,0.1));
                
                //光照模型
                half3 diffuse = var_MainCol * var_RampTex * _LightColor0.rgb * _AmbCol * _AmbInt;
                
                //光照模型（阴影）
                half ShadowAtten = LIGHT_ATTENUATION(i);
                half3 Shadow = lerp(var_MainCol * _ShadowCol, var_MainCol, ShadowAtten);
                //返回结果
                half3 finalRBG = 0.0;
                #ifdef LIGHTMAP_ON //获取Lightmap
                UnityIndirect indirectLight;
                half3 lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));
                indirectLight.specular = 0;
                finalRBG = diffuse * Shadow * lerp(_LimCol1,_LimCol2,lm);
                #else
                finalRBG = diffuse * Shadow;
                #endif 
                
                return half4(finalRBG,0.0);
            }
            ENDCG
        }
        //额外光源的处理
		Pass
		{
			Tags{"LightMode" = "ForwardAdd"}
			//混合模式，在帧缓存中与之前的光照结果进行叠加
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			//multi_compile_fwdadd保证shader中使用光照衰减等光照变量可以被正确赋值
			#pragma multi_compile_fwdadd
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

            uniform sampler2D  _MainCol;
            uniform sampler2D  _LightRampTex;
            uniform sampler2D  _OutLinethickness;
            uniform half4  _ShadowCol;

            struct VertexInput {
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half2 uv    : TEXCOORD0;
			};

            struct VertexOutput {
                half4 pos            : SV_POSITION;
                half4 posWS          : TEXCOORD0;
                half3 normalDir      : TEXCOORD1;  
                LIGHTING_COORDS(2,3)
                half2 uv             : TEXCOORD4;
			};

            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.pos = UnityObjectToClipPos( v.vertex );
                o.posWS=mul(unity_ObjectToWorld, v.vertex);
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                o.uv=v.uv;
                return o;
			}

            half4 frag(VertexOutput i) : COLOR {
				//准备向量
                half3 nDir = normalize(i.normalDir); 
				#ifdef USING_DIRECTIONAL_LIGHT  //平行光下可以直接获取世界空间下的光照方向
					fixed3 lDir = normalize(_WorldSpaceLightPos0.xyz);
				#else  //其他光源下_WorldSpaceLightPos0代表光源的世界坐标，与顶点的世界坐标的向量相减可得到世界空间下的光照方向
					fixed3 lDir = normalize(_WorldSpaceLightPos0.xyz - i.posWS.xyz);
				#endif
                //准备中间数据（点积结果）
                half nDotl = dot(nDir,lDir); 
                half Lambert = max(0.0,nDotl);
                //贴图采样
                half3 var_MainCol = tex2D(_MainCol,i.uv).rgb;
                half3 var_RampTex = tex2D(_LightRampTex,half2(Lambert,0.1));
                
                //光照模型（直接光照）（阴影）
                half ShadowAtten = LIGHT_ATTENUATION(i);
                half3 Shadow = lerp(var_MainCol * _ShadowCol, var_MainCol, ShadowAtten);

				#ifdef USING_DIRECTIONAL_LIGHT  //平行光下不存在光照衰减，恒值为1
					fixed atten = 1.0;
				#else
					#if defined (POINT)    //点光源的光照衰减计算
						//unity_WorldToLight内置矩阵，世界空间到光源空间变换矩阵。与顶点的世界坐标相乘可得到光源空间下的顶点坐标
						half3 lightCoord = mul(unity_WorldToLight, half4(i.posWS.xyz, 1)).xyz;
                        // 使用点到光源中心距离的平方dot(lightCoord, lightCoord)构成二维采样坐标(r,r)，对衰减纹理_LightTexture0采样。
						fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
					#elif defined (SPOT)   //聚光灯的光照衰减计算
						half4 lightCoord = mul(unity_WorldToLight, half4(i.posWS.xyz, 1));
						//(lightCoord.z > 0)：聚光灯的深度值小于等于0时，则光照衰减为0
						//_LightTextureB0：如果该光源使用了cookie，则衰减查找纹理则为_LightTextureB0
					fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
					#else
						fixed atten = 1.0;
					#endif
				#endif

                //返回结果
                half3 finalRBG = var_MainCol * var_RampTex * Shadow * _LightColor0.rgb;
                
				//这里不再计算环境光，在上个pass中已做计算
				return fixed4(finalRBG * atten, 1.0);
			}
				ENDCG
        }
    }
    FallBack "Diffuse"
}
