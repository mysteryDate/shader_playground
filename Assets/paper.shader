Shader "custom/paper"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_WaterTex ("Water Texture", 2D) = "white" {}
		_Focus ("Focus", float) = 1
		_Floats ("Floats", vector) = (1,1,1,1)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;

			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float dist : TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _WaterTex;
			float4 _WaterTex_ST;

			float2 _HitPoint;
			float _Focus;
			float4 _Floats;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.dist = distance(v.uv, _HitPoint);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed4 watercol = tex2D(_WaterTex, i.uv);
				float d = distance(i.uv, _HitPoint);
				col = col / pow(d / _Floats.x, _Focus);
				return watercol;
			}
			ENDCG
		}
	}
}
