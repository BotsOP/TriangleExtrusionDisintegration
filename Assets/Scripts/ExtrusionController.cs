using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using VInspector;

public class ExtrusionController : MonoBehaviour
{
    [SerializeField] private Material material;
    [SerializeField, Range(-0.5f, 0)] private float extrusion;
    [SerializeField, Range(0, 1)] private float topSize;

    private void OnValidate()
    {
        material.SetFloat("_Extrusion", extrusion);
        material.SetFloat("_TopSize", topSize);
    }
}
