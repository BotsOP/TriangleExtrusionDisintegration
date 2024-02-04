#ifndef UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED
#define UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
// For Directional lights, _LightDirection is used when applying shadow Normal Bias.
// For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
float3 _LightDirection;
float3 _LightPosition;

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


struct GeometryOutput
{
    float2 uv           : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
};

float4 GetShadowPositionHClip(Varyings input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output;

    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.texcoord = input.texcoord;
    
    return output;
}

GeometryOutput VaryingsToGeometry(Varyings input)
{
    GeometryOutput output = (GeometryOutput)0;

    UNITY_SETUP_INSTANCE_ID(input);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.positionCS = GetShadowPositionHClip(input);

    return output;
}

[maxvertexcount(24)]
void ShadowPassGeometry(triangle Varyings inputs[3], inout TriangleStream<GeometryOutput> outputStream)
{
    Varyings baseVertex1 = inputs[0];
    Varyings baseVertex2 = inputs[1];
    Varyings baseVertex3 = inputs[2];
    
    GeometryOutput outputVertex1 = VaryingsToGeometry(baseVertex1);
    GeometryOutput outputVertex2 = VaryingsToGeometry(baseVertex2);
    GeometryOutput outputVertex3 = VaryingsToGeometry(baseVertex3);

    Varyings baseVertex4 = inputs[0];
    Varyings baseVertex5 = inputs[1];
    Varyings baseVertex6 = inputs[2];
    
    float4 avgNormal = float4((baseVertex1.normalOS.xyz + baseVertex2.normalOS.xyz + baseVertex3.normalOS.xyz) / 3, 1);
    baseVertex4.positionOS = baseVertex1.positionOS + avgNormal * _Extrusion;
    baseVertex5.positionOS = baseVertex2.positionOS + avgNormal * _Extrusion;
    baseVertex6.positionOS = baseVertex3.positionOS + avgNormal * _Extrusion;
    float4 avgTopPos = (baseVertex4.positionOS + baseVertex5.positionOS + baseVertex6.positionOS) / 3;
    baseVertex4.positionOS = lerp(avgTopPos, baseVertex4.positionOS, _TopSize);
    baseVertex5.positionOS = lerp(avgTopPos, baseVertex5.positionOS, _TopSize);
    baseVertex6.positionOS = lerp(avgTopPos, baseVertex6.positionOS, _TopSize);

    GeometryOutput outputVertex4 = VaryingsToGeometry(baseVertex4);
    GeometryOutput outputVertex5 = VaryingsToGeometry(baseVertex5);
    GeometryOutput outputVertex6 = VaryingsToGeometry(baseVertex6);

    //Base
    outputStream.Append(outputVertex1);
    outputStream.Append(outputVertex2);
    outputStream.Append(outputVertex3);

    outputStream.RestartStrip();

    //Top
    outputStream.Append(outputVertex5);
    outputStream.Append(outputVertex4);
    outputStream.Append(outputVertex6);

    outputStream.RestartStrip();

    //Extrusion face 1
    baseVertex1.texcoord = float2(0, 0);
    baseVertex2.texcoord = float2(1, 0);
    baseVertex4.texcoord = float2(0, 1);
    baseVertex5.texcoord = float2(1, 1);

    outputVertex1 = VaryingsToGeometry(baseVertex1);
    outputVertex2 = VaryingsToGeometry(baseVertex2);
    outputVertex4 = VaryingsToGeometry(baseVertex4);
    outputVertex5 = VaryingsToGeometry(baseVertex5);
    
    outputStream.Append(outputVertex2);
    outputStream.Append(outputVertex1);
    outputStream.Append(outputVertex5);
     
    outputStream.Append(outputVertex5);
    outputStream.Append(outputVertex4);
    outputStream.Append(outputVertex1);

    outputStream.RestartStrip();
    
    //Extrusion face 2
    baseVertex2.texcoord = float2(0, 0);
    baseVertex3.texcoord = float2(1, 0);
    baseVertex5.texcoord = float2(0, 1);
    baseVertex6.texcoord = float2(1, 1);

    outputVertex2 = VaryingsToGeometry(baseVertex2);
    outputVertex3 = VaryingsToGeometry(baseVertex3);
    outputVertex5 = VaryingsToGeometry(baseVertex5);
    outputVertex6 = VaryingsToGeometry(baseVertex6);
    
    outputStream.Append(outputVertex3);
    outputStream.Append(outputVertex2);
    outputStream.Append(outputVertex6);
     
    outputStream.Append(outputVertex6);
    outputStream.Append(outputVertex5);
    outputStream.Append(outputVertex2);

    outputStream.RestartStrip();
    
    //Extrusion face 3
    baseVertex1.texcoord = float2(0, 0);
    baseVertex3.texcoord = float2(1, 0);
    baseVertex4.texcoord = float2(0, 1);
    baseVertex6.texcoord = float2(1, 1);

    outputVertex1 = VaryingsToGeometry(baseVertex1);
    outputVertex3 = VaryingsToGeometry(baseVertex3);
    outputVertex4 = VaryingsToGeometry(baseVertex4);
    outputVertex6 = VaryingsToGeometry(baseVertex6);
    
    outputStream.Append(outputVertex1);
    outputStream.Append(outputVertex3);
    outputStream.Append(outputVertex4);
     
    outputStream.Append(outputVertex4);
    outputStream.Append(outputVertex6);
    outputStream.Append(outputVertex3);
}

half4 ShadowPassFragment(GeometryOutput input) : SV_TARGET
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);

#ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
#endif

    return 0;
}

#endif
