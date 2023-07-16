Shader "Unlit/crystals"{
    Properties {
        [Header(Texture)]
            _MainTex("RGB:基础颜色A:环境遮罩",2D) = "white"{}
            _EmitTex("发光贴图",2D) = "black"{}
            _NormaTex("法线贴图",2D) = "black"{}
            _DirtyTex("斑点贴图",2D) = "black"{}

        [Header(Diffuse)]
            _MainCol("基本色", color) = (1.0,1.0,1.0,1.0)
            _AmbientCol("环境光颜色", color) = (1.0,1.0,1.0,1.0)
        [Header(Specular)]
            _SpecPow("高光次幂",range(1,90)) = 34
            _SpecInt("高光强度",range(1,30)) = 15
            _CubeMap("环境球", Cube) = "white"{}
            _Smoothness("Smoothness", Range(0,1)) = 0.26
            _AOInt ("环境光遮蔽强度", Range(0, 1)) = 0.45
            _AOCol("环境光遮蔽颜色", color) = (1.0,1.0,1.0,1.0)
            _Height("视差高度", Range(0, 1)) = 0.08
            _Color("视差颜色", color) = (1.0,1.0,1.0,1.0)
            _FresnelPow ("菲涅尔次幂", Range(0, 2)) = 1.1
        [Header(Emission)]
        _EmitInt("自发光强度",Range(0,1)) = 0.2
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
            //投影需要的
            #include "AutoLight.cginc"   
            #include "Lighting.cginc"
            //
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #pragma multi_compile_fwdbase_fullshadows
            #pragma target 3.0

            //获取参数
            //Texture
            uniform sampler2D  _MainTex;uniform half4 _MainTex_ST;
            uniform sampler2D  _EmitTex;uniform half4 _EmitTex_ST;
            uniform sampler2D  _NormaTex;uniform half4 _NormaTex_ST;
            uniform sampler2D  _DirtyTex;

            //Diffuse
            uniform half4 _MainCol;
            uniform half4 _AmbientCol;
            //Specular
            uniform half _SpecPow;
            uniform half _SpecInt;
            uniform half _Smoothness;
            uniform sampler3D _CubeMap;
            uniform half _AOInt;
            uniform half4 _AOCol;
            uniform half _Height;
            uniform half4 _Color;
            uniform half _FresnelPow;
            //Emission
            uniform half _EmitInt;

            //输入结构
            struct VertexInput {
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half4 tangent  : TANGENT;
                half2 uv0    : TEXCOORD0;
            };
            //输出结构
            struct VertexOutput {
                half4 pos    : SV_POSITION;
                half4 posWS  : TEXCOORD0;
                half3 tDirWS : TEXCOORD1;
                half3 bDirWS : TEXCOORD2; 
                half3 nDirWS : TEXCOORD3;  
                half2 uv0    : TEXCOORD4;
                half2 offset    : TEXCOORD5;
                LIGHTING_COORDS(5,6)
            };
            //输出结构>>>顶点Shader>>>输出结构
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;                                                    //建立输出结构
                o.pos = UnityObjectToClipPos( v.vertex );                                           //顶点位置OS>CS
                o.posWS=mul(unity_ObjectToWorld, v.vertex);                                          //顶点位置OS>WS
                o.nDirWS = UnityObjectToWorldNormal(v.normal);                                       //法线方向OS>WS
                o.tDirWS = normalize( mul( unity_ObjectToWorld, half4( v.tangent.xyz, 0.0 ) ).xyz );//切线方向
                o.bDirWS = normalize(cross(o.nDirWS, o.tDirWS) * v.tangent.w);                      //副切线方向
                TRANSFER_VERTEX_TO_FRAGMENT(o)                                                      //投影相关
                //将视角向量变换到切线空间
                half3 viewDir = normalize(UnityWorldSpaceViewDir(o.posWS));
                TANGENT_SPACE_ROTATION;
                float2 BumpOffset = mul(rotation , viewDir).xy * -_Height;
                //计算UV信息
                o.offset = BumpOffset;
                o.uv0=v.uv0;                                                                          //传递uv
                return o;                                                                           //返回输出结构
            }
            //输出结构>>>像素
            half4 frag(VertexOutput i) : COLOR {
                //准备向量
                half3 nDirTS = UnpackNormal(tex2D(_NormaTex,i.uv0 * _NormaTex_ST.xy + _NormaTex_ST.zw)).rgb;
                half3x3 TBN = half3x3(i.tDirWS,i.bDirWS,i.nDirWS);                                //计算TBN矩阵
                half3 nDirWS = normalize(mul(nDirTS,TBN));
                half3 lDirWS = normalize (_WorldSpaceLightPos0.xyz);
                half3 vDirWS = normalize (_WorldSpaceCameraPos.xyz - i.posWS);                     //视线方向
                half3 hDir = normalize (vDirWS+lDirWS);
                half3 vrDirWS = reflect(-vDirWS,nDirWS);

                //准备中间数据（点积结果）
                half nDotl = dot(nDirWS,lDirWS); 
                half nDoth = dot(nDirWS,hDir);
                half nDotv = dot(nDirWS,vDirWS);                                                    //菲涅尔需要的
                //纹理采样
                half4 var_MainTex = tex2D(_MainTex,i.uv0 * _MainTex_ST.xy + _MainTex_ST.zw);
                half3 var_EmitTex = tex2D(_EmitTex,i.uv0 * _EmitTex_ST.xy + _EmitTex_ST.zw);
                half3 rough = var_EmitTex.b;


                
                //光照模型
                    //环境漫反射
                    half3 ambient =  _AmbientCol;
                    //光照漫反射
                    half3 baseCol = var_MainTex.rgb * ambient ;
                    half lambert = max(0.0,nDotl);
                    half Shadow = LIGHT_ATTENUATION(i);
                    //漫反射混合
                    half3 diff = baseCol * lambert * _LightColor0 * Shadow * _MainCol.rgb;
                    //环境镜面反射
                    //使用反射探头，通过BoxProjectedCubemapDirection函数修正reflectDir
                    vrDirWS = BoxProjectedCubemapDirection(vrDirWS, i.posWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                    half4 rgbm = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, vrDirWS);
                    half3 reflection = DecodeHDR(rgbm, unity_SpecCube0_HDR);
                    half ao = var_MainTex.a;
                    half3 aocol = lerp(_AOCol,_AOCol * 3.0,ao);
                    half3 fresnel = max(0.0,1-nDotv) * _FresnelPow * var_MainTex.rgb;
                    half3 diffenvCol = aocol * _AOInt + fresnel * _AmbientCol;
                    //光照镜面反射
                    half BlinnPhong = pow(max(0.0,nDoth),rough * _SpecPow);
                    half spec = BlinnPhong * max(0.0,nDotl);
                    //spec = max(spec,fresnel);
                    spec = spec * _SpecInt;
                    half3 specenvCol = var_MainTex.rgb * spec * _LightColor0;
                    //镜面反射混合
                    half3 Spec = specenvCol + diffenvCol;
                    //视差映射
	                half bumpcolor = tex2D(_MainTex, (-i.uv0 * _MainTex_ST.xy + _MainTex_ST.zw) + i.offset*0.4).a;
                    half3 BumpColor = lerp(_AOCol,_AOCol * 2.3,bumpcolor)* _Color.rgb;
                    half3 dirty = tex2D(_DirtyTex, (i.uv0 + i.offset*0.8)).rgb;
                    dirty = lerp(dirty,0,fresnel.r*1.4);
                    BumpColor = BumpColor + dirty;
                    diff = diff + BumpColor;//混合
                    //自发光
                    half3 emis = var_EmitTex.r * _EmitInt;
                    //最终混合
                    half3 finalRGB = lerp(diff, reflection, _Smoothness) + Spec + emis;
                //返回结果
                return half4(finalRGB,1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}