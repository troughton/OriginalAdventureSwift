//
//  Shaders.metal
//  OriginalAdventureMetal
//
//  Created by Thomas Roughton on 22/11/15.
//  Copyright (c) 2015 Thomas Roughton. All rights reserved.
//

#include <metal_stdlib>
#include "Structs.h"
#include "MetalStructs.h"
#include "LightComputations.h"

using namespace metal;
using namespace Ingenero;

struct VertexInput {
    packed_float3 position;
    packed_float3 normal;
    packed_float2 textureCoordinate;
};

vertex VertexInOut forwardRendererVertexShader(uint vid [[ vertex_id ]],
                                    device VertexInput *positionData  [[ buffer(0) ]],
                                     device packed_float3* tangent  [[ buffer(1) ]],
                                    constant ModelMatrices *matrices [[buffer(2)]]) {
    VertexInOut outVertex;
    
    VertexInput input = positionData[vid];
    float4 cameraSpacePosition = matrices->modelToCameraMatrix * float4(input.position, 1);
    outVertex.cameraSpacePosition = cameraSpacePosition.xyz;
    outVertex.position = matrices->projectionMatrix * cameraSpacePosition;
    outVertex.textureCoordinate = input.textureCoordinate * matrices->textureRepeat.xy;
    outVertex.normal = half3(matrices->normalModelToCameraMatrix * float3(input.normal));
    
    float3 mBPrime = cross(input.normal, tangent[vid]);
    
    outVertex.tangentToCameraSpaceMatrixC1 = half3(normalize(matrices->modelToCameraRotationMatrix * float3(tangent[vid])));
    outVertex.tangentToCameraSpaceMatrixC2 = half3(normalize(matrices->modelToCameraRotationMatrix * mBPrime));
    outVertex.tangentToCameraSpaceMatrixC3 = half3(normalize(matrices->modelToCameraRotationMatrix * float3(input.normal)));
    
    return outVertex;
};

constexpr sampler s = sampler(coord::normalized,
                              address::repeat,
                              filter::linear,
                              mip_filter::linear);


fragment float4 forwardRendererFragmentShader(VertexInOut inFrag [[stage_in]],
                                             constant LightBlock *lighting [[buffer(0)]],
                                             texture2d<half> ambientTexture [[texture(0)]],
                                             texture2d<float> diffuseTexture [[texture(1)]],
                                             texture2d<half> specularTexture [[texture(2)]],
                                             texture2d<half> normalTexture [[texture(3)]]) {
    half3x3 tangentToCameraSpaceMatrix = half3x3(inFrag.tangentToCameraSpaceMatrixC1, inFrag.tangentToCameraSpaceMatrixC2, inFrag.tangentToCameraSpaceMatrixC3);
    
    float2 textureCoordinate = inFrag.textureCoordinate;

    float4 diffuse = diffuseTexture.sample(s, textureCoordinate);
    
    if (diffuse.a < 0.001f) {
        return float4(0, 0, 0, 0);
    }
    
    half4 specular = specularTexture.sample(s, textureCoordinate);
    half4 ambientColour = ambientTexture.sample(s, textureCoordinate);
    half4 localSpaceNormal = normalTexture.sample(s, textureCoordinate) * 2 - 1;
    half3 surfaceNormal = normalize(tangentToCameraSpaceMatrix * localSpaceNormal.xyz);
    
    float3 totalLighting = diffuse.rgb * lighting->ambientIntensity.rgb;
    
    if (abs(ambientColour.a - 1) < 0.01) { // ~= 1
        totalLighting += float3(ambientColour.rgb);
    }
    
    for (int light = 0; light < MaxLights; light++) {
        PerLightData lightData = lighting->lights[light];
        if (length_squared(lightData.positionInCameraSpace) == 0) { break; }
        totalLighting += ComputeLighting(inFrag.cameraSpacePosition, lightData, surfaceNormal, diffuse, specular);
    }
    
    return float4(totalLighting, diffuse.a);
};