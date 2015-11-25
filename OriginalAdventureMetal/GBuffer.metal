//
//  GBuffer.metal
//  OriginalAdventure
//
//  Created by Thomas Roughton on 25/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#include <metal_stdlib>
#include "MetalStructs.h"

using namespace metal;
using namespace Ingenero;

fragment GBuffers gBufferFragmentShader(VertexInOut inFrag [[stage_in]],
                                             texture2d<half> ambientTexture [[texture(0)]],
                                             texture2d<float> diffuseTexture [[texture(1)]],
                                             texture2d<half> specularTexture [[texture(2)]],
                                             texture2d<half> normalTexture [[texture(3)]]) {
    
    constexpr sampler s = sampler(coord::normalized,
                                  address::repeat,
                                  filter::linear,
                                  mip_filter::linear);
    
    half3x3 tangentToCameraSpaceMatrix = half3x3(inFrag.tangentToCameraSpaceMatrixC1, inFrag.tangentToCameraSpaceMatrixC2, inFrag.tangentToCameraSpaceMatrixC3);
    
    float2 textureCoordinate = inFrag.textureCoordinate;
    
    float4 diffuse = diffuseTexture.sample(s, textureCoordinate);
    
    half4 specular = specularTexture.sample(s, textureCoordinate);
    half4 ambientColour = ambientTexture.sample(s, textureCoordinate);
    half4 localSpaceNormal = normalTexture.sample(s, textureCoordinate) * 2 - 1;
    half3 surfaceNormal = normalize(tangentToCameraSpaceMatrix * localSpaceNormal.xyz);
    
    GBuffers output;
    output.diffuse = diffuse;
    output.normal = surfaceNormal;
    output.specular = specular;
    output.light = float4(ambientColour);
    
    return output;
};