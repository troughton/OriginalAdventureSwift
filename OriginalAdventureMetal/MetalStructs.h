//
//  MetalStructs.h
//  OriginalAdventure
//
//  Created by Thomas Roughton on 25/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#ifndef MetalStructs_h
#define MetalStructs_h

#include <simd/simd.h>

#ifdef __cplusplus

namespace Ingenero
{
    using namespace simd;
    
    typedef struct
    {
        float4 diffuse [[color(2)]]; //channel 4 is the specular tint towards the diffuse
        half4 normal [[color(1)]]; //channel 4 is the specularity
        float4 light [[color(0)]];
    } GBuffers;
    
    struct VertexInOut
    {
        float2  textureCoordinate;
        half3  normal;
        float3  cameraSpacePosition;
        float4  position [[position]];
        half3 tangentToCameraSpaceMatrixC1;
        half3 tangentToCameraSpaceMatrixC2;
        half3 tangentToCameraSpaceMatrixC3;
    };
}

#endif

#endif /* MetalStructs_h */
