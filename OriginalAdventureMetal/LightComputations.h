//
//  LightComputations.h
//  OriginalAdventure
//
//  Created by Thomas Roughton on 25/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#ifndef LightComputations_h
#define LightComputations_h
#include <simd/simd.h>
#include "Structs.h"

#ifdef __cplusplus

using namespace simd;

float3 ComputeLighting(float3, PerLightData, half3, float4, half4);

#endif
#endif /* LightComputations_h */
