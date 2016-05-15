//
// GPGPU kernels for point cloud
//
// Texture format:
//
// _PositionTex.xyz = position
// _PositionTex.w   = any number
//
// _VelocityTex.xyz = velocity vector
// _VelocityTex.w   = 0
//
Shader "custom/Kernel"
{
    Properties
    {
        _InputTex ("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"
    #include "ClassicNoise3D.cginc"

    sampler2D _InputTex;
    float _RandomSeed;

    // simply returns a zero vector, instead of freaking out
	float3 norm(float3 vec) {
		float len = length(vec);
		float3 norm = (len == 0.0) ? vec : vec/len;
		return norm;
	}

    // Pseudo random number generator
    float nrand(float2 uv, float salt)
    {
        uv += float2(salt, _RandomSeed);
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }

    // Pass 0: clear texture
    float4 clear_tex(v2f_img i) : SV_Target 
    {
        return float4(0, 0, 0, 1);
    }

    // Pass 1: blend tex
    float4 frag_init_velocity(v2f_img i) : SV_Target 
    {
        fixed4 col = tex2D(_InputTex, i.uv);
        return col + 0.01;
    }

    ENDCG

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment clear_tex
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_init_velocity
            ENDCG
        }
    }
}
  