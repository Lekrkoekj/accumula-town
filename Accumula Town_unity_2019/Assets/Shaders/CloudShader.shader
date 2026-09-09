Shader "Custom/CloudShaderRetro"
{
    Properties
    {
        _TextureSize("Texture Size", float) = 0.1
        _Strength("Cloud Strength", float) = 2.15
        _MovementSpeed("Movement Speed", float) = 2
        _Mask("Mask", 2D) = "white" {}
        _MaskStrength("Mask Strength", float) = 3.94

        // --- Retro controls ---
        _PixelSize("Pixel Size (world units)", float) = 8
        _ColorLevels("Color Levels (posterize steps, 0 = off)", float) = 5

        _HeightNoiseOffset("Height Noise Offset", float) = 0.5
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

            float _PixelSize;
            float _ColorLevels;

            float _HeightNoiseOffset;

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

            float hash1(float n)
            {
                return frac(sin(n) * 43758.5453123);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Get object world space Y position
                float objectHeight = unity_ObjectToWorld._m13;

                float2 animatedPos = i.worldPosition.xz + _Time.y * _MovementSpeed;

                // Randomize noise offset
                float2 randomOffset = float2(
                    hash1(objectHeight * 12.9898),
                    hash1(objectHeight * 78.233)
                ) * _HeightNoiseOffset * 100.0;

                animatedPos += randomOffset;

                // Pixelate
                float2 pixelatedPos = floor(animatedPos / _PixelSize) * _PixelSize;

                float cloud = pow(
                    simplex(pixelatedPos * _TextureSize),
                    _Strength
                );

                // Limit the amount of colors used to make it look more retro
                if (_ColorLevels > 0)
                {
                    cloud = round(cloud * _ColorLevels) / _ColorLevels;
                }

                // Mask
                float mask = tex2D(_Mask, i.uv).r;
                cloud *= pow(mask, _MaskStrength);

                return fixed4(cloud, cloud, cloud, 0.0);
            }
            ENDCG
        }
    }
}