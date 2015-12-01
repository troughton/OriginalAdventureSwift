//
//  Lighting.metal
//  OriginalAdventure
//
//  Created by Thomas Roughton on 25/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#include <metal_stdlib>
#include "LightComputations.h"
#include "Structs.h"
#include "MetalStructs.h"

using namespace metal;
using namespace Ingenero;

struct LightingVertexOutput {
    float4 position [[position]];
    float4 cameraDirection;
};


float3 CalculateCameraSpacePositionFromWindow(float, float3, constant float2&, constant float3&);
float3 CalculateCameraSpacePositionFromWindow(float windowZ,
                                              float3 cameraDirection,
                                              constant float2 &depthRange,
                                              constant float3 &matrixTerms) {
    float ndcZ = (2.0 * windowZ - depthRange.x - depthRange.y) /
    (depthRange.y - depthRange.x);
    float eyeZ = matrixTerms.x / ((matrixTerms.y * ndcZ) - matrixTerms.z);
    return cameraDirection * eyeZ;
}

vertex LightingVertexOutput pointLightVertex(device float4 *posData [[buffer(0)]],
                                            constant float2 &halfSizeNearPlane [[buffer(1)]],
                                            constant float4x4 &worldToClipMatrix [[buffer(2)]],
                                            uint vid [[vertex_id]] ) {
    LightingVertexOutput output;
    float4 position = posData[vid];
    float4 clipPosition = worldToClipMatrix * position;
    output.position = clipPosition;
    output.cameraDirection = float4(clipPosition.xy * halfSizeNearPlane, -1, 0);
    return output;
}

vertex LightingVertexOutput compositionVertex(constant float2 *posData [[buffer(0)]],
                                      constant float2 &halfSizeNearPlane [[buffer(1)]],
                                      uint vid [[vertex_id]] ) {
    LightingVertexOutput output;
    float2 position = posData[vid];
    output.position = float4(position, 0.0f, 1.0f);
    output.cameraDirection = float4(position * halfSizeNearPlane, -1, 1);
    return output;
}

fragment float4 lightFrag(LightingVertexOutput in [[stage_in]],
                                     constant LightBlock &lighting [[buffer(0)]],
                                     constant float2 &depthRange [[buffer(1)]],
                                     constant float3 &matrixTerms [[buffer(2)]],
                                     texture2d<float> depthTexture [[texture(2)]],
                                     texture2d<float> diffuseTexture [[texture(1)]],
                                     texture2d<float> normalTexture [[texture(0)]]
                                     ) {
    constexpr sampler s = sampler(coord::pixel);
    
    float depth = depthTexture.sample(s, in.position.xy).r;
    float3 cameraSpacePosition = CalculateCameraSpacePositionFromWindow(depth, in.cameraDirection.xyz, depthRange, matrixTerms);
    
    float4 diffuse = diffuseTexture.sample(s, in.position.xy);
    float specularTint = diffuse.w;
    half3 specularColour = half3(mix(float3(1), diffuse.rgb, specularTint));
  
    half4 normal = half4(normalTexture.sample(s, in.position.xy) * 2 - 1);
    half specularity = normal.w;
    
    float3 totalLighting = diffuse.rgb * lighting.ambientIntensity.rgb;
    totalLighting += ComputeLighting(cameraSpacePosition, lighting.lights[0], normal.xyz, diffuse, half4(specularColour, specularity));
    
    return float4(totalLighting, 1);
}