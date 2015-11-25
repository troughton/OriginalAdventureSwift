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
        float4 diffuse [[color(0)]];
        half3 normal [[color(1)]];
        half4 specular [[color(2)]];
        float4 light [[color(3)]];
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
