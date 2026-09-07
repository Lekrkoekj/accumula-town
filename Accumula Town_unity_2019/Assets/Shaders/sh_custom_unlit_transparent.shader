// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "BeatSaber/Lit Glow Cutout Dithered"
{
    Properties
    {
        _Color ("Color Day", Color) = (1,1,1,1)
        _ColorNight ("Color Night", Color) = (1,1,1,1)
        _Tex ("Texture", 2D) = "white" {}
        _Bloom ("Glow (Beat Saber Bloom)", Range (0, 1)) = 0
        _Alpha ("Opacity Fade", Range(0, 1)) = 1
        _Cutout ("Cutout Threshold", Range (0, 1)) = 0.5
        _Ambient ("Ambient Lighting", Range (0, 1)) = 0.2
        _DayNightCycle("Day/Night Cycle", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" "IgnoreProjector"="True" }
        LOD 100
        Cull Off

        // Forward Base Pass
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
                half4 color : COLOR;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 scrPos : TEXCOORD1;
                float3 normal : NORMAL;
                float4 worldPos : TEXCOORD3;
                half4 color : COLOR;
                SHADOW_COORDS(4)
                UNITY_FOG_COORDS(5)

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _Color;
            float4 _ColorNight;
            float _Bloom;
            float _Alpha;
            float _Cutout;
            float _Ambient;
            float _DayNightCycle;

            sampler2D _Tex;
            float4 _Tex_ST;

            // 4x4 Bayer Matrix screen-door dithering function
            void ApplyDither(float4 scrPos, float fadeAlpha)
            {
                // Screen pixel coordinates adjusted for VR viewport dimensions
                float2 screenPos = (scrPos.xy / scrPos.w) * _ScreenParams.xy;
                int2 ditherCoord = int2(fmod(screenPos.x, 4.0), fmod(screenPos.y, 4.0));

                const float dither[16] = {
                     1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
                    13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
                     4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
                    16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
                };

                int index = ditherCoord.x + ditherCoord.y * 4;
                if (fadeAlpha < dither[index])
                {
                    discard;
                }
            }
            
            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _Tex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.color = v.color;
                o.scrPos = ComputeScreenPos(o.pos);

                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);

                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                fixed4 baseColor = lerp(_ColorNight, _Color, _DayNightCycle);
                fixed4 tex = tex2D(_Tex, i.uv);
                fixed4 col = baseColor * tex;

                // Hard cutout discard based on texture alpha
                if (col.a < _Cutout) discard;

                // Dither fade check (combining _Alpha and vertex alpha)
                float totalAlpha = saturate(_Alpha * i.color.a);
                ApplyDither(i.scrPos, totalAlpha);

                // Lighting & Shadow Calculation
                float3 normal = normalize(i.normal);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos.xyz);

                float NdotL = max(0.0, dot(normal, lightDir));
                float3 diffuse = _LightColor0.rgb * NdotL * atten;

                float3 albedo = col.rgb * i.color.rgb;
                float3 ambient = (ShadeSH9(float4(normal, 1.0)) + _Ambient) * albedo;
                float3 finalRGB = ambient + (albedo * diffuse);

                // RGB is visible color; Alpha is strictly Beat Saber Bloom intensity
                fixed4 finalCol = fixed4(finalRGB, _Bloom);
                UNITY_APPLY_FOG(i.fogCoord, finalCol);

                return finalCol;
            }
            ENDCG
        }

        // Shadow Caster Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"

            struct appdata_caster
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord : TEXCOORD0;
                half4 color : COLOR;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD1;
                float4 scrPos : TEXCOORD2;
                half4 color : COLOR;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _Tex;
            float4 _Tex_ST;
            float4 _Color;
            float4 _ColorNight;
            float _DayNightCycle;
            float _Cutout;
            float _Alpha;

            void ApplyDither(float4 scrPos, float fadeAlpha)
            {
                float2 screenPos = (scrPos.xy / scrPos.w) * _ScreenParams.xy;
                int2 ditherCoord = int2(fmod(screenPos.x, 4.0), fmod(screenPos.y, 4.0));

                const float dither[16] = {
                     1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
                    13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
                     4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
                    16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
                };

                int index = ditherCoord.x + ditherCoord.y * 4;
                if (fadeAlpha < dither[index]) discard;
            }

            v2f vert(appdata_caster v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.uv = TRANSFORM_TEX(v.texcoord, _Tex);
                o.color = v.color;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                o.scrPos = ComputeScreenPos(o.pos);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                fixed4 baseColor = lerp(_ColorNight, _Color, _DayNightCycle);
                fixed4 tex = tex2D(_Tex, i.uv);
                fixed4 col = baseColor * tex;

                if (col.a < _Cutout) discard;

                float totalAlpha = saturate(_Alpha * i.color.a);
                ApplyDither(i.scrPos, totalAlpha);

                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
    Fallback "Transparent/Cutout/VertexLit"
}