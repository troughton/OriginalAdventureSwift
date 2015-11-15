//
//  LightStructs.h
//  OriginalAdventure
//
//  Created by Thomas Roughton on 19/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#ifndef LightStructs_h
#define LightStructs_h

#import "Math.h"
#import <simd/simd.h>

#ifdef DEFERRED_RENDERING
#define MaxLights 1
#else
#define MaxLights 32
#endif

typedef struct PerLightData {
    float positionInCameraSpace[4]; //16 bytes
    float intensity[4]; //where xyz are the intensity colour vectors and w is unused.
    float falloff[4];
} PerLightData;

typedef struct LightBlock {
    float ambientIntensity[4];
    PerLightData lights[MaxLights];
} LightBlock;

typedef struct MaterialStruct {
    //Packed into a single vec4
    float ambientColour[4]; //where ~0 is false and ~1 is true.
   
    float diffuseColour[4];
    
    //Packed into a single vec4
    float specularColour[4];
    
    int flags;
} MaterialStruct;

#endif /* LightStructs_h */
