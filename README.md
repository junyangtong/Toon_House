![image](https://github.com/junyangtong/Toon_House/assets/135015047/6201e582-49e4-4eb9-b317-d395798eee1f)# Toon_House
插画风格渲染
（左图为参考图，右图为还原效果）
[图片]
[图片]

一、模型
1.根据场景图在blender中进行建模
 
[图片]
[图片]
- 2.为实现树的卡通效果对模型进行了法线映射，使模型的亮部和暗部更加整体。（左图为用于法线映射的模型）
[图片]
[图片]

二、贴图
在blender中展开uv，导入sp进行贴图绘制（只有一层basecolor）
 
[图片]

三、Unity shader
1. 基础光照
使用Lambert光照模型
half Lambert = max(0.0,nDotl);
2. 采样ramp图
在室外和室内不同的场景中使用了不同的ramp图
 
[图片]
通过采样这些ramp贴图来达到卡通效果
half3 var_RampTex = tex2D(_RampTex,half2(Lambert,0.1));
3.多光源光照与烘焙lightmap
添加pass
Tags{"LightMode" = "ForwardAdd"}
进行额外光源的处理，再与前面的pass进行混合实现多光源光照效果
在unity lighting中烘焙光照贴图并在shader中获取
 #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON 
#ifdef LIGHTMAP_ON //获取Lightmap
                UnityIndirect indirectLight;
                half3 lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));
                indirectLight.specular = 0;
                finalRBG = diffuse * Shadow * lerp(_LimCol1,_LimCol2,lm);
                #else
                finalRBG = diffuse * Shadow;
                #endif 
实现效果如下
[图片]
四、后处理
1.计算描边
获取深度和法线纹理
sampler2D _CameraDepthNormalsTexture;//声明获取深度+法线纹理
使用深度和法线纹理计算描边
// 法线检测
            half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x;
            int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1;
            // 深度检测
            float diffDepth = abs(centerDepth - sampleDepth) * _Sensitivity.y;
 
            int isSameDepth = diffDepth < 0.1 * centerDepth;
            
            return isSameNormal * isSameDepth ? 1.0 : 0.0;
2.断线效果
此外我观察到场景原画中的描边是断断续续的，我采样了一张noise图来实现这种效果
实现效果如下
[图片]
3.为描边添加颜色
获取屏幕颜色，提高饱和度，再降低明度，叠加到描边颜色上
[图片]
4.调整饱和度
完成
[图片]
