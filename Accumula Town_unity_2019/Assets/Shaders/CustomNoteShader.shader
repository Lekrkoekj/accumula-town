Shader "Vivify/CustomNote"
{
    Properties
    {
        [Toggle(DEBRIS)] _Debris ("Debris", Int) = 0
        _CutoutEdgeWidth("Cutout Edge Width", Range(0,0.1)) = 0.02

        [Header(Top Half Gradient)]
        _Color ("Top Gradient Top Color", Color) = (1, 0, 0, 1)

        [Header(Middle Line)]
        _MidLineColor ("Middle Line Color", Color) = (0.05, 0.05, 0.05, 1)
        _MidLineWidth ("Middle Line Thickness", Range(0.0, 0.5)) = 0.08

        [Header(Bottom Half Gradient)]
        _BottomColorTop ("Bottom Gradient Top Color", Color) = (0.9, 0.9, 0.9, 1)
        _BottomColorBottom ("Bottom Gradient Bottom Color", Color) = (0.6, 0.6, 0.6, 1)
        _BottomColorTint ("Bottom Tint Towards Top Color", Range(0.0, 1.0)) = 0.0

        [Header(Model Bounds)]
        _ModelExtentY ("Model Half-Height", Float) = 0.5

        /*
        These are fed in by Vivify per note.
        Vivify will attempt to feed these values into every child of a note prefab.
        */
        _Cutout ("Cutout", Range(0,1)) = 1
        _CutPlane ("Cut Plane", Vector) = (0, 0, 1, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Cull Off

        // -------------------------------------------------------------
        // Main Forward Base Pass (Rendering Note)
        // -------------------------------------------------------------
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma shader_feature DEBRIS

            #include "UnityCG.cginc"
            #include "Assets/VivifyTemplate/Utilities/Shader Functions/Noise.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 localPos : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float3, _Color)
                UNITY_DEFINE_INSTANCED_PROP(float, _Cutout)
                UNITY_DEFINE_INSTANCED_PROP(float4, _CutPlane)
            UNITY_INSTANCING_BUFFER_END(Props)

            float _CutoutEdgeWidth;
            float4 _MidLineColor;
            float _MidLineWidth;
            float4 _BottomColorTop;
            float4 _BottomColorBottom;
            float _BottomColorTint;
            float _ModelExtentY;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.localPos = v.vertex.xyz;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                float Cutout = UNITY_ACCESS_INSTANCED_PROP(Props, _Cutout);
                float3 NoteColor = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
                float4 CutPlane = UNITY_ACCESS_INSTANCED_PROP(Props, _CutPlane);

                float c = 0;

                #if DEBRIS
                    float3 samplePoint = i.localPos + CutPlane.xyz * CutPlane.w;
                    float planeDistance = dot(samplePoint, CutPlane.xyz) / length(CutPlane.xyz);
                    c = planeDistance - Cutout * 0.25;
                #else
                    float noise = simplex(i.localPos * 2);
                    c = noise - Cutout;
                #endif

                clip(c);

                // Cutout edge now returns alpha = 0.0
                if (c < _CutoutEdgeWidth) {
                    return fixed4(1, 1, 1, 0);
                }

                float y = i.localPos.y;
                float halfLine = _MidLineWidth * 0.5;
                float3 basePattern = float3(0, 0, 0);

                if (abs(y) <= halfLine)
                {
                    basePattern = _MidLineColor.rgb;
                }
                else if (y > halfLine)
                {
                    float3 topColorTop = NoteColor;
                    float3 topColorBottom = NoteColor * 0.8584906;

                    float tTop = saturate((y - halfLine) / max(0.001, _ModelExtentY - halfLine));
                    basePattern = lerp(topColorBottom, topColorTop, tTop);
                }
                else
                {
                    // Blend bottom gradient stops toward the note's dynamic top color
                    float3 tintedBottomTop = lerp(_BottomColorTop.rgb, NoteColor, _BottomColorTint);
                    float3 tintedBottomBottom = lerp(_BottomColorBottom.rgb, NoteColor, _BottomColorTint);

                    float tBottom = saturate((-y - halfLine) / max(0.001, _ModelExtentY - halfLine));
                    basePattern = lerp(tintedBottomTop, tintedBottomBottom, tBottom);
                }

                float lighting = pow(i.localPos.y + 0.8, 4);

                // End result set to alpha = 0.0 while preserving RGB
                return fixed4(basePattern * lighting, 0.0);
            }
            ENDCG
        }

        // -------------------------------------------------------------
        // Shadow Caster Pass (Casts Shadows & Honors Slices/Dissolve)
        // -------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            #pragma shader_feature DEBRIS

            #include "UnityCG.cginc"
            #include "Assets/VivifyTemplate/Utilities/Shader Functions/Noise.cginc"

            struct appdata_shadow
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f_shadow
            {
                V2F_SHADOW_CASTER;
                float3 localPos : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float3, _Color)
                UNITY_DEFINE_INSTANCED_PROP(float, _Cutout)
                UNITY_DEFINE_INSTANCED_PROP(float4, _CutPlane)
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f_shadow vert(appdata_shadow v)
            {
                v2f_shadow o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.localPos = v.vertex.xyz;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            float4 frag(v2f_shadow i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                float Cutout = UNITY_ACCESS_INSTANCED_PROP(Props, _Cutout);
                float4 CutPlane = UNITY_ACCESS_INSTANCED_PROP(Props, _CutPlane);

                float c = 0;

                #if DEBRIS
                    float3 samplePoint = i.localPos + CutPlane.xyz * CutPlane.w;
                    float planeDistance = dot(samplePoint, CutPlane.xyz) / length(CutPlane.xyz);
                    c = planeDistance - Cutout * 0.25;
                #else
                    float noise = simplex(i.localPos * 2);
                    c = noise - Cutout;
                #endif

                // Discard pixels so sliced/dissolved portions don't cast floating phantom shadows
                clip(c);

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
}