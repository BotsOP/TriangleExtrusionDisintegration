#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// keep this file in sync with LitGBufferPass.hlsl

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct GeometryOutput
{
    float2 uv                       : TEXCOORD0;

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD1;
    #endif

    float3 normalWS                 : TEXCOORD2;
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
    #endif
    float3 viewDirWS                : TEXCOORD4;

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
    #else
    half  fogFactor                 : TEXCOORD5;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD6;
    #endif

    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                : TEXCOORD7;
    #endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
    #ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV : TEXCOORD9; // Dynamic lightmap UVs
    #endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(GeometryOutput input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    #if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
    #endif
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
#else
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#else
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#endif

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.tangentOS = input.tangentOS;
    output.texcoord = input.texcoord;
    output.staticLightmapUV = input.staticLightmapUV;
    output.dynamicLightmapUV = input.dynamicLightmapUV;

    return output;
}

GeometryOutput VaryingsToGeometry(Varyings input)
{
    GeometryOutput output = (GeometryOutput)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#else
    output.fogFactor = fogFactor;
#endif

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

void CalculateNormalAndTangent(float3 v1, float3 v2, float3 v3, out float3 normal, out float4 tangent)
{
    float3 edge1 = v2 - v1;
    float3 edge2 = v3 - v1;

    normal = normalize(cross(edge1, edge2));

    tangent = float4(normalize(cross(normal, edge1)), 1);
}

[maxvertexcount(24)]
void LitPassGeometry(triangle Varyings inputs[3], inout TriangleStream<GeometryOutput> outputStream)
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
    
    outputStream.Append(outputVertex2);
    outputStream.Append(outputVertex1);
    outputStream.Append(outputVertex5);
     
    outputStream.Append(outputVertex5);
    outputStream.Append(outputVertex4);
    outputStream.Append(outputVertex1);

    outputStream.RestartStrip();
    
    //Extrusion face 2

    float3 normal;
    float4 tangent;
    CalculateNormalAndTangent(baseVertex3.positionOS, baseVertex2.positionOS, baseVertex6.positionOS, normal, tangent);
    
    baseVertex2.normalOS = normal;
    baseVertex2.tangentOS = tangent;
    baseVertex3.normalOS = normal;
    baseVertex3.tangentOS = tangent;
    baseVertex5.normalOS = normal;
    baseVertex5.tangentOS = tangent;
    baseVertex6.normalOS = normal;
    baseVertex6.tangentOS = tangent;

    outputVertex1 = VaryingsToGeometry(baseVertex1);
    outputVertex2 = VaryingsToGeometry(baseVertex2);
    outputVertex3 = VaryingsToGeometry(baseVertex3);
    outputVertex4 = VaryingsToGeometry(baseVertex4);
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

    CalculateNormalAndTangent(baseVertex1.positionOS, baseVertex3.positionOS, baseVertex4.positionOS, normal, tangent);
    
    baseVertex1.normalOS = normal;
    baseVertex1.tangentOS = tangent;
    baseVertex3.normalOS = normal;
    baseVertex3.tangentOS = tangent;
    baseVertex4.normalOS = normal;
    baseVertex4.tangentOS = tangent;
    baseVertex6.normalOS = normal;
    baseVertex6.tangentOS = tangent;

    outputVertex1 = VaryingsToGeometry(baseVertex1);
    outputVertex2 = VaryingsToGeometry(baseVertex2);
    outputVertex3 = VaryingsToGeometry(baseVertex3);
    outputVertex4 = VaryingsToGeometry(baseVertex4);
    outputVertex5 = VaryingsToGeometry(baseVertex5);
    outputVertex6 = VaryingsToGeometry(baseVertex6);
    
    outputStream.Append(outputVertex1);
    outputStream.Append(outputVertex3);
    outputStream.Append(outputVertex4);
     
    outputStream.Append(outputVertex4);
    outputStream.Append(outputVertex6);
    outputStream.Append(outputVertex3);
}

// Used in Standard (Physically Based) shader
void LitPassFragment(
    GeometryOutput input
    , out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

#ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
#endif

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif

    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, IsSurfaceTypeTransparent(_Surface));

    outColor = color;

#ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
#endif
}

#endif
