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
    float4 _InputTex_ST;
    float4 _InputTex_TexelSize;
    float _RandomSeed;

    float2 _HitPoint;

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

    //base input structs
     struct vertexInput {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
     };
     struct vertexOutput {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float2 taps[4] : TEXCOORD1;
     };

     // vertex function
     vertexOutput vert(vertexInput v){
        vertexOutput o;

        o.uv = TRANSFORM_TEX(v.uv, _InputTex);
        o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

        o.taps[0] = o.uv + half2(_InputTex_TexelSize.x,0);
        o.taps[1] = o.uv + half2(0,_InputTex_TexelSize.y);
        o.taps[2] = o.uv - half2(_InputTex_TexelSize.x,0);
        o.taps[3] = o.uv - half2(0,_InputTex_TexelSize.y);

        return o;
     }

    // Pass 0: clear texture
    float4 clear_tex(v2f_img i) : SV_Target 
    {
        return float4(0, 0, 0, 1);
    }

    // Pass 1: blend tex
    float4 spread(vertexOutput i) : SV_Target 
    {
        fixed4 col = tex2D(_InputTex, i.uv);

        float4 tex = tex2D(_InputTex, i.taps[0].xy);
        tex += tex2D(_InputTex, i.taps[1].xy);
        tex += tex2D(_InputTex, i.taps[2].xy);
        tex += tex2D(_InputTex, i.taps[3].xy);

        return tex/4;
    }

    // Pass 2: add droplet
    float4 drop(vertexOutput i) : SV_Target 
    {
    	fixed4 col = tex2D(_InputTex, i.uv);
    	float d = distance(i.uv, _HitPoint);
    	if(d < 0.01) {
    		col = fixed4(1,1,1,1);
    	}
//    	return float4(1,1,0,1);
        return col / pow(d / 0.1, 3);
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
            #pragma vertex vert
            #pragma fragment spread
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment drop
            ENDCG
        }
    }
}
  