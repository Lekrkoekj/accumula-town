Shader "Custom/CloudShader"
{
    Properties
    {
        _TextureSize("Texture Size", float) = 0.1
        _Strength("Cloud Strength", float) = 2.15
        _MovementSpeed("Movement Speed", float) = 2
        _Mask("Mask", 2D) = "white" {}
        _MaskStrength("Mask Strength", float) = 3.94

        [Header(Retro Pixelation)]
        _GridResolution("Pixel Grid Density", float) = 64.0
        _ColorBands("Color Posterization Steps (0 = Off)", float) = 4.0

        [Header(Height Adjustments)]
        _HeightSpeedDamping("Height Speed Damping", float) = 0.05
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
                float objectHeight : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float _TextureSize;
            float _Strength;
            float _MovementSpeed;

            sampler2D _Mask;
            float4 _Mask_ST;
            float4 _Mask_TexelSize;
            float _MaskStrength;

            float _GridResolution;
            float _ColorBands;

            float _HeightSpeedDamping;

            // Pseudo-random hash: maps a 1D scalar to a 2D random offset in range [0, 1000]
            float2 hash21(float p)
            {
                float3 p3 = frac(p * float3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.xx + p3.yz) * p3.zy) * 1000.0;
            }

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPosition = localToWorld(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Mask);

                // Sample GameObject's origin Y in world space
                o.objectHeight = unity_ObjectToWorld[1].w;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Height-based speed scaling: higher in world space moves slower
                float height = i.objectHeight;
                float effectiveSpeed = _MovementSpeed / (1.0 + max(0.0, height * _HeightSpeedDamping));

                // Completely pseudo-random 2D coordinate offset seeded by height
                float2 randomNoiseOffset = hash21(height);

                // 1. Calculate full-scale noise domain coordinates
                float2 noiseDomain = (i.worldPosition.xz + randomNoiseOffset + (_Time.y * effectiveSpeed)) * _TextureSize;

                // 2. Snap directly inside noise coordinate space
                float gridRes = max(_GridResolution, 1.0);
                float2 snappedNoiseCoord = (floor(noiseDomain * gridRes) + 0.5) / gridRes;

                // 3. Sample procedural noise
                float cloud = pow(simplex(snappedNoiseCoord), _Strength);

                // 4. Sample mask
                float mask = tex2Dlod(_Mask, float4(i.uv, 0.0, 0.0)).r;

                // 5. Apply mask
                cloud *= pow(mask, _MaskStrength);

                // 6. Palette posterization
                if (_ColorBands > 1.0)
                {
                    cloud = floor(cloud * _ColorBands) / _ColorBands;
                }

                return fixed4(cloud, cloud, cloud, 0.0);
            }
            ENDCG
        }
    }
}