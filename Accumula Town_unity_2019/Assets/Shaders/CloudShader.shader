Shader "Custom/CloudShader"
{
    Properties
    {
        _TextureSize("Texture Size", float) = 1
        _Strength("Cloud Strength", float) = 1
        _MovementSpeed("Movement Speed", float) = 1
        _Mask("Mask", 2D) = "white" {}
        _MaskStrength("Mask Strength", float) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }

        Blend One OneMinusSrcColor
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Assets/VivifyTemplate/Utilities/Shader Functions/Math.cginc"
            #include "Assets/VivifyTemplate/Utilities/Shader Functions/Noise.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 worldPosition : TEXCOORD0;
                float2 uv : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float _TextureSize;
            float _Strength;
            float _MovementSpeed;

            sampler2D _Mask;
            float4 _Mask_ST;
            float _MaskStrength;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPosition = localToWorld(v.vertex);

                o.uv = TRANSFORM_TEX(v.uv, _Mask);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Cloud noise
                float cloud = pow(
                    simplex((i.worldPosition.xz + _Time.y * _MovementSpeed) * _TextureSize),
                    _Strength
                );

                // Mask (use red channel for grayscale)
                float mask = tex2D(_Mask, i.uv).r;

                // Apply mask
                cloud *= pow(mask, _MaskStrength);

                // RGB keeps the cloud appearance, Alpha is explicitly 0
                return fixed4(cloud, cloud, cloud, 0.0);
            }
            ENDCG
        }
    }
}