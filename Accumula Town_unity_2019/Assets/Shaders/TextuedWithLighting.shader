// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Vivify/Textured With Lighting"
{
    Properties
    {
        _Color ("Color Day", Color) = (1,1,1,1)
        _ColorNight ("Color Night", Color) = (1,1,1,1)
        _Tex ("Texture", 2D) = "white" {}
        _Glow ("Glow", Range (0, 1)) = 0
        _Ambient ("Ambient Lighting", Range (0, 1)) = 0.2
        _DayNightCycle("Day/Night Cycle", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        // Forward Base Pass: Handles ambient, main directional light & shadow receiving
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float4 worldPos : TEXCOORD1;
                SHADOW_COORDS(2)
                UNITY_FOG_COORDS(3)

                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _Color;
            float4 _ColorNight;
            float _Glow;
            float _Ambient;
            float _DayNightCycle;

            sampler2D _Tex;
            float4 _Tex_ST;
            
            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Tex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);

                // Computes shadow map sample coordinates
                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);

                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

                // Real-time shadow attenuation (1 = lit, 0 = in shadow)
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos.xyz);

                // Lambertian diffuse based on the active scene light
                float NdotL = max(0.0, dot(normal, lightDir));
                float3 diffuse = _LightColor0.rgb * NdotL * atten;

                // Base albedo blending day/night tint with the texture
                fixed4 baseColor = lerp(_ColorNight, _Color, _DayNightCycle);
                fixed4 tex = tex2D(_Tex, i.uv);
                fixed3 albedo = baseColor.rgb * tex.rgb;

                // Combine scene ambient + custom ambient slider + direct shadow-attenuated lighting
                float3 ambient = (ShadeSH9(float4(normal, 1.0)) + _Ambient) * albedo;
                float3 finalRGB = ambient + (albedo * diffuse);

                fixed4 finalCol = fixed4(finalRGB, _Glow);
                UNITY_APPLY_FOG(i.fogCoord, finalCol);

                return finalCol;
            }
            ENDCG
        }

        // Shadow Caster Pass: Allows this object to cast shadows onto other objects
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
            #include "UnityCG.cginc"

            struct v2f
            {
                V2F_SHADOW_CASTER;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}