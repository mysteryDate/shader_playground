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
        _PositionTex ("-", 2D) = ""{}
        _VelocityTex ("-", 2D) = ""{}
    }

    CGINCLUDE

    #pragma multi_compile _ ENABLE_SWIRL
    #pragma multi_compile _ ENABLE_CLUMP

    #include "UnityCG.cginc"
    #include "ClassicNoise3D.cginc"

    sampler2D _InputTex;
	sampler2D _VertexTex;

    sampler2D _PositionTex;
    sampler2D _VelocityTex;
    float4 _PositionTex_TexelSize;
    float4 _VelocityTex_TexelSize;

    float2 _Acceleration; // (min, max)
    float _Damp;
    float3 _AttractPos;
    float _Spread;
    float3 _Flow;
    float4 _NoiseParams; // (frequency, amplitude, animation, variance)
    float2 _SwirlParams; // (strength, density)
    float _RandomSeed;
    float2 _TimeParams; // (current, delta)
    
    float _ClumpStrength;
    float _HomeStrength;
    float _RandomStrength;
    
    // The height and width of the texture
    float _Dimension;
    float _GroupSize;
    
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

    // Position dependant force field
    float3 position_force(float3 p, float2 uv)
    {
        p = p * _NoiseParams.x + _TimeParams.x * _NoiseParams.z + _RandomSeed;
        float3 uvc = float3(uv.x, 0, 7.919) * _NoiseParams.w;
        float nx = cnoise(p + uvc.xyz);
        float ny = cnoise(p + uvc.yzx);
        float nz = cnoise(p + uvc.zxy);
        return float3(nx, ny, nz);// * _NoiseParams.y + 0.1*float3(sin(2 * 3.14 * uv.y + _TimeParams.x),sin(2 * 3.14* uv.y + 1.7 * _TimeParams.x),sin(2 * 3.14* uv.y + 3 * _TimeParams.x));
    }

    // Attractor position
    float3 attract_point(float2 uv)
    {
        float3 r = float3(nrand(uv, 0), nrand(uv, 1), nrand(uv, 2));
        return _AttractPos + (r - (float3)0.5) * _Spread;
    }

    // Pass 0: position initialization
    float4 frag_init_position(v2f_img i) : SV_Target 
    {
        return float4(0, 0, 0, nrand(i.uv.yy, 3));
    }

    // Pass 1: velocity initialization
    float4 frag_init_velocity(v2f_img i) : SV_Target 
    {
        return (float4)0;
    }

    // Pass 2: position update
    float4 frag_update_position(v2f_img i) : SV_Target 
    {
        // Fetch the current position (u=0) or the previous position (u>0).
        float2 uv_prev = float2(_PositionTex_TexelSize.x, 0);
//        float4 p = tex2D(_PositionTex, i.uv - uv_prev);
        float4 p = tex2D(_PositionTex, i.uv);

        // Fetch the velocity vector.
        float3 v = tex2D(_VelocityTex, i.uv).xyz;

        // Use the flow vector or add swirl vector.
        float3 flow = _Flow;
#if ENABLE_SWIRL
        flow += position_force(p.xyz * _SwirlParams.y, i.uv) * _SwirlParams.x;
#endif
        // Add the velocity (u=0) or the flow vector (u>0).
        float u_0 = i.uv.x < _PositionTex_TexelSize.x;
//        p.xyz += lerp(flow, v, u_0) * _TimeParams.y;
		p.xyz += (v + _AttractPos) * _TimeParams.y;

        return p;
    }

    // Pass 3: velocity update
    float4 frag_update_velocity(v2f_img i) : SV_Target 
    {
        // Only needs the leftmost pixel.
//        float2 uv = i.uv * float2(0, 1);
        float2 uv = i.uv;

        // Fetch the current position/velocity.
        float3 p = tex2D(_PositionTex, uv).xyz;
        float3 v = tex2D(_VelocityTex, uv).xyz;
        
        float3 fToNeighbors = float3(0,0,0);
#if ENABLE_CLUMP
        // Vectors to neighbors (on the texture)
        float3 pUp 		= tex2D(_PositionTex, uv - float2(0, _PositionTex_TexelSize.y)).xyz - p;
        pUp 			= norm(pUp) / pow(max(0.5, dot(pUp, pUp)), 2);
        float3 pDown 	= tex2D(_PositionTex, uv + float2(0, _PositionTex_TexelSize.y)).xyz - p;
        pDown 			= norm(pDown) / pow(max(0.5, dot(pDown, pDown)), 2);
        float3 pLeft 	= tex2D(_PositionTex, uv - float2(0, _PositionTex_TexelSize.y * 2)).xyz - p;
        pLeft			= norm(pLeft) / pow(max(0.5, dot(pLeft, pLeft)), 2);
        float3 pRight 	= tex2D(_PositionTex, uv + float2(0, _PositionTex_TexelSize.y * 2)).xyz - p;
        pRight			= norm(pRight) / pow(max(0.5, dot(pRight, pRight)), 2);
        
//        fToNeighbors = pUp + pDown + pLeft + pRight;
//        fToNeighbors = pUp;
#endif

		// Bird shapes
		float pixelNumber = ((i.uv.x - 0.5/_Dimension) * _Dimension + i.uv.y - 0.5/_Dimension) * _Dimension;
		float birdPosition = fmod(pixelNumber, _GroupSize);
		float centerNumber = floor(pixelNumber / _GroupSize) * _GroupSize + floor(_GroupSize/2);
//		centerNumber = _GroupSize;
		float centerUVx = floor(centerNumber/_Dimension) / _Dimension + 0.5/_Dimension;
		float centerUVy = (centerNumber - (centerUVx * _Dimension * _Dimension)) / _Dimension + 0.5/_Dimension;
		float3 pCenter = tex2D(_PositionTex, float2(uv.x,0.5)).xyz;
		fToNeighbors = (pCenter + float3(0.2*(0.5-uv.y), abs(0.5-uv.y)*sin((1-nrand(float2(uv.x, 0), 6)/10)*_TimeParams.x),0)) - p;
       
        
        // Attracting Poitns
        float3 goal = tex2D(_VertexTex, i.uv.xy).xyz;
        float3 fToGoal = goal - p;
        
        float3 fToRandom = position_force(p, uv);
        
        // Acceleration force
        float3 acf = fToGoal * _HomeStrength + fToNeighbors * _ClumpStrength + fToRandom * _RandomStrength;// + attract_point(i.uv) - goal;
        
        // Acceleration scale factor
        float acs = lerp(_Acceleration.x, _Acceleration.y, nrand(float2(uv.x, uv.y), 4));

        // Damping
        v *= (1.0 - _Damp * _TimeParams.y);

        // Acceleration
		v += acf * acs * _TimeParams.y;
//		float len = min(length(acf), _Acceleration.y);
//		acf = norm(acf) * len;
//        v += acf * _TimeParams.y;

        return float4(v, 0);
    }

    ENDCG

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_init_position
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
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_update_position
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_update_velocity
            ENDCG
        }
    }
}
  