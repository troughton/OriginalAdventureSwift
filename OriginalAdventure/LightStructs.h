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

#define MaxLights 32

typedef struct PerLightData {
    float positionInCameraSpace[4]; //16 bytes
    float intensity[4]; //where xyz are the intensity colour vectors and w is the falloff; 16 bytes
} PerLightData;

typedef struct LightBlock {
    float ambientIntensity[4];
    int numDynamicLights;
    int padding1;
    float lightAttenuationFactor;
    float padding2;
    PerLightData lights[MaxLights];
} LightBlock;

#endif /* LightStructs_h */
