//
//  Structs.h
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#ifndef Structs_h
#define Structs_h

#include <simd/simd.h>

#ifdef DEFERRED_RENDERING
#define MaxLights 1
#else
#define MaxLights 32
#endif

#ifdef __cplusplus
extern "C" {
#endif
    typedef struct PerLightData {
        vector_float4 positionInCameraSpace; //16 bytes
        vector_float4 intensity; //where xyz are the intensity colour vectors and w is unused.
        vector_float4 falloff;
    } PerLightData;
    
    typedef struct LightBlock {
        vector_float4 ambientIntensity;
        PerLightData lights[MaxLights];
    } LightBlock;
    
    typedef struct MaterialStruct {
        //Packed into a single vec4
        vector_float4 ambientColour;
        vector_float4 diffuseColour;
        
        //Packed into a single vec4
        vector_float4 specularColour;
        
        int flags;
    } MaterialStruct;

    typedef struct {
        matrix_float3x3 modelToCameraRotationMatrix;
        matrix_float3x3 normalModelToCameraMatrix;
        matrix_float4x4 modelToCameraMatrix;
        matrix_float4x4 projectionMatrix;
    } ModelMatrices;
    
#ifdef __cplusplus
}
#endif

#endif /* Structs_h */
