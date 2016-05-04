using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class paperController : MonoBehaviour {

	public Material paperMaterial;
	RenderTexture _tex1;
	RenderTexture _tex2;

	public Shader _waterColorShader;
	Material _kernelMaterial;

	public int textureSize;

	// Use this for initialization
	void Start () {

		_tex1 = CreateBuffer ();
		_tex2 = CreateBuffer ();
		_kernelMaterial = CreateMaterial (_waterColorShader);

		Graphics.Blit (null, _tex1, _kernelMaterial, 0);
		Graphics.Blit (null, _tex2, _kernelMaterial, 0);
	}
	
	// Update is called once per frame
	void Update () {

		if( Input.GetMouseButtonDown(0) )
		{
			Ray ray = Camera.main.ScreenPointToRay( Input.mousePosition );
			RaycastHit hit;

			if( Physics.Raycast( ray, out hit, 100 ) )
			{
				Debug.Log( hit.textureCoord );
				paperMaterial.SetVector ("_HitPoint", hit.textureCoord);
			}
		}
	
		StepKernel (Time.time, Time.smoothDeltaTime);

	}

	void StepKernel(float time, float deltaTime) {
		// Ping ponging, Gagnam-style
		var curTex = _tex1;
		_tex1 = _tex2;
		_tex2 = curTex;

		Material m = _kernelMaterial;
		m.SetTexture ("_InputTex", _tex1);
		m.SetVector ("_TimeParams", new Vector2 (time, deltaTime));
//		Graphics.Blit (null, _tex2, m, 1);
	}

	Material CreateMaterial(Shader shader) {
		Material material = new Material (shader);
		material.hideFlags = HideFlags.DontSave;
		return material;
	}

	RenderTexture CreateBuffer()
	{
		var format = RenderTextureFormat.ARGBFloat;
		var buffer = new RenderTexture (textureSize, textureSize, 0, format);
		buffer.hideFlags = HideFlags.DontSave;
		buffer.filterMode = FilterMode.Bilinear;
		buffer.wrapMode = TextureWrapMode.Clamp;

		return buffer;
	}
}
