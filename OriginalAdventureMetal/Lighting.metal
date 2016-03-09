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
    float3 cameraDirection [[center_no_perspective]];
};


float3 CalculateCameraSpacePositionFromWindow(float, float3, constant float2&, constant float3&);
float3 CalculateCameraSpacePositionFromWindow(float windowZ,
                                              float3 cameraDirection,
                                              constant float2 &depthRange,
                                              constant float3 &matrixTerms) {
    float eyeZ = -matrixTerms.x / ((matrixTerms.y * windowZ) - matrixTerms.z);
    return cameraDirection * eyeZ;
}

vertex LightingVertexOutput pointLightVertex(device float4 *posData [[buffer(0)]],
                                            constant float3 &nearPlane [[buffer(1)]],
                                            constant float4x4 &worldToClipMatrix [[buffer(2)]],
                                            uint vid [[vertex_id]] ) {
    LightingVertexOutput output;
    float4 position = posData[vid];
    float4 clipPosition = worldToClipMatrix * position;
    output.position = clipPosition;
    
    output.cameraDirection = float3(clipPosition.xy/clipPosition.w * nearPlane.xy, nearPlane.z);
    return output;
}

vertex LightingVertexOutput compositionVertex(constant float2 *posData [[buffer(0)]],
                                      constant float3 &nearPlane [[buffer(1)]],
                                      uint vid [[vertex_id]] ) {
    LightingVertexOutput output;
    float2 position = posData[vid];
    output.position = float4(position, 0.0f, 1.0f);
    output.cameraDirection = float3(position * nearPlane.xy, nearPlane.z);
    return output;
}

fragment float4 lightFrag(LightingVertexOutput in [[stage_in]],
                                     constant PerLightData &light [[buffer(0)]],
                                     constant float2 &depthRange [[buffer(1)]],
                                     constant float3 &matrixTerms [[buffer(2)]],
                                     texture2d<float> depthTexture [[texture(2)]],
                                     texture2d<float> diffuseTexture [[texture(1)]],
                                     texture2d<float> normalTexture [[texture(0)]]
                                     ) {
    constexpr sampler s = sampler(coord::pixel);
    float depth = depthTexture.sample(s, in.position.xy).r;
    float3 cameraSpacePosition = CalculateCameraSpacePositionFromWindow(depth, in.cameraDirection, depthRange, matrixTerms);
    
    float4 diffuse = diffuseTexture.sample(s, in.position.xy);
    float specularTint = diffuse.w;
    float3 specularColour = float3(mix(float3(1), diffuse.rgb, specularTint));
  
    float4 normalAndSpecularity = normalTexture.sample(s, in.position.xy);
    float3 normal = normalAndSpecularity.xyz * 2 - 1;
    normal.z = 1 - length_squared(normal.xy); //faster than normalize() since it avoids a sqrt
    float specularity = normalAndSpecularity.w;
    
    float3 totalLighting = ComputeLighting(cameraSpacePosition, light, normal, diffuse, float4(specularColour, specularity));
    
    return float4(totalLighting, 1);
}