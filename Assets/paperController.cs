using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class paperController : MonoBehaviour {

	public Material paperMaterial;

	// Use this for initialization
	void Start () {
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
	
	}
}
