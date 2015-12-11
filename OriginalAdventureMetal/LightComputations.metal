//
//  LightComputations.metal
//  OriginalAdventure
//
//  Created by Thomas Roughton on 25/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#include <metal_stdlib>
#include "MetalStructs.h"
#include "Structs.h"
#include "LightComputations.h"

using namespace metal;

struct AttenuationResult {
    float3 lightDirection;
    float attenuation;
};

AttenuationResult ComputeAttenuation(float3,
                                     float3,
                                     float3);

AttenuationResult ComputeAttenuation(float3 objectPosition,
                                     float3 lightPosition,
                                     float3 falloff) {
    
    float3 vectorToLight = lightPosition - objectPosition;
    float lightDistanceSqr = dot(vectorToLight, vectorToLight);
    float inverseLightDistance = rsqrt(lightDistanceSqr);
    
    AttenuationResult result;
    result.lightDirection = vectorToLight * inverseLightDistance;
    result.attenuation = 1 / (falloff.x + falloff.y / inverseLightDistance + falloff.z * lightDistanceSqr);
    
    return result;
}

struct AngleNormalHalfResult {
    float3 lightIntensity;
    float angleNormalHalf;
    float cosAngIncidence;
};


AngleNormalHalfResult ComputeAngleNormalHalf(float3, float3, PerLightData);

AngleNormalHalfResult ComputeAngleNormalHalf(float3 cameraSpacePosition, float3 surfaceNormal, PerLightData lightData) {
    float3 lightDirection;
    AngleNormalHalfResult result;
    
    if (lightData.positionInCameraSpace.w < 0.0001) { //DirectionalLight
        lightDirection = float3(lightData.positionInCameraSpace.xyz);
        result.lightIntensity = lightData.intensity.rgb;
    }
    else {
        AttenuationResult attenuationResult = ComputeAttenuation(cameraSpacePosition,
                                                                 lightData.positionInCameraSpace.xyz, lightData.falloff.xyz);
        lightDirection = float3(attenuationResult.lightDirection);
        result.lightIntensity = attenuationResult.attenuation * lightData.intensity.rgb;
    }
    float3 viewDirection = float3(normalize(-cameraSpacePosition));
    
    float cosAngIncidenceTemp = dot(surfaceNormal, lightDirection);
    result.cosAngIncidence = max(cosAngIncidenceTemp, 0.f); //clamp it to 0
    float3 halfAngle = normalize(lightDirection + viewDirection);
    float angleNormalHalf = acos(dot(halfAngle, surfaceNormal));
    result.angleNormalHalf = angleNormalHalf;
    
    return result;
}

float3 ComputeLighting(float3 cameraSpacePosition, PerLightData lightData, float3 surfaceNormal, float4 diffuse, float4 specular) {
    
    AngleNormalHalfResult angleNormalHalfResult = ComputeAngleNormalHalf(cameraSpacePosition, surfaceNormal, lightData);
    
    float exponent = angleNormalHalfResult.angleNormalHalf / float(specular.w);
    exponent = -(exponent * exponent);
    float gaussianTerm = exp(exponent);
    
    gaussianTerm = angleNormalHalfResult.cosAngIncidence != 0.0f ? gaussianTerm : 0.0;
    
    float3 lighting = diffuse.rgb * angleNormalHalfResult.lightIntensity * angleNormalHalfResult.cosAngIncidence;
    lighting += float3(specular.rgb) * angleNormalHalfResult.lightIntensity * gaussianTerm;
    
    return lighting;
}