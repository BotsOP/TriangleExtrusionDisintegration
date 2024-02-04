using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using VInspector;

public class ExtrusionController : MonoBehaviour
{
    [SerializeField] private Material material;
    [SerializeField, Range(-0.5f, 0)] private float extrusion;

    private void OnValidate()
    {
        material.SetFloat("_Extrusion", extrusion);
    }

    [Button]
    public void UpdateValues()
    {
        material.SetFloat("_Extrusion", extrusion);
    }
}
