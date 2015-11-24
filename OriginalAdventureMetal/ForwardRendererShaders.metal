//
//  Shaders.metal
//  OriginalAdventureMetal
//
//  Created by Thomas Roughton on 22/11/15.
//  Copyright (c) 2015 Thomas Roughton. All rights reserved.
//

#include <metal_stdlib>
#include "Structs.h"

using namespace metal;

struct VertexInOut
{
    float2  textureCoordinate;
    float3  normal;
    float3  cameraSpacePosition;
    float4  position [[position]];
    float3 tangentToCameraSpaceMatrixC1;
    float3 tangentToCameraSpaceMatrixC2;
    float3 tangentToCameraSpaceMatrixC3;
};

struct VertexInput {
    packed_float3 position;
    packed_float3 normal;
    packed_float2 textureCoordinate;
};
    

vertex VertexInOut forwardRendererVertexShader(uint vid [[ vertex_id ]],
                                    device VertexInput *positionData  [[ buffer(0) ]],
                                     device packed_float3* tangent  [[ buffer(1) ]],
                                    constant ModelMatrices *matrices [[buffer(2)]])
{
    VertexInOut outVertex;
    
    VertexInput input = positionData[vid];
    float4 cameraSpacePosition = matrices->modelToCameraMatrix * float4(input.position, 1);
    outVertex.cameraSpacePosition = cameraSpacePosition.xyz;
    outVertex.position = matrices->projectionMatrix * cameraSpacePosition;
    outVertex.textureCoordinate = input.textureCoordinate;
    outVertex.normal = matrices->normalModelToCameraMatrix * float3(input.normal);
    
    float3 mBPrime = cross(input.normal, tangent[vid]);
    
    outVertex.tangentToCameraSpaceMatrixC1 = normalize(matrices->modelToCameraRotationMatrix * float3(tangent[vid]));
    outVertex.tangentToCameraSpaceMatrixC2 = normalize(matrices->modelToCameraRotationMatrix * mBPrime);
    outVertex.tangentToCameraSpaceMatrixC3 = normalize(matrices->modelToCameraRotationMatrix * float3(input.normal));
    
    return outVertex;
};

struct AttenuationResult {
    float3 lightDirection;
    float attenuation;
};

float4 diffuseColour(constant MaterialStruct*);
float4 diffuseColour(constant MaterialStruct* material) {
    return material->diffuseColour;
}

float4 ambientColour(constant MaterialStruct*);
float4 ambientColour(constant MaterialStruct* material) {
    return material->ambientColour;
}

float4 specularColour(constant MaterialStruct*);
float4 specularColour(constant MaterialStruct* material) {
    return material->specularColour;
}

bool useNormalMap(constant MaterialStruct*);
bool useNormalMap(constant MaterialStruct* material) {
    return (material->flags & (1 << 3)) != 0;
}

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


AngleNormalHalfResult ComputeAngleNormalHalf(VertexInOut, PerLightData);

AngleNormalHalfResult ComputeAngleNormalHalf(VertexInOut vert, PerLightData lightData) {
    float3 lightDirection;
    AngleNormalHalfResult result;
    
    if (lightData.positionInCameraSpace.w < 0.0001) { //DirectionalLight
        lightDirection = lightData.positionInCameraSpace.xyz;
        result.lightIntensity = lightData.intensity.rgb;
    }
    else {
        AttenuationResult attenuationResult = ComputeAttenuation(vert.cameraSpacePosition,
                                               lightData.positionInCameraSpace.xyz, lightData.falloff.xyz);
        lightDirection = attenuationResult.lightDirection;
        result.lightIntensity = attenuationResult.attenuation * lightData.intensity.rgb;
    }
    float3 viewDirection = normalize(-vert.cameraSpacePosition);
    float3 surfaceNormal = normalize(vert.normal); //to be modified to make use of normal maps
    
    
    float cosAngIncidenceTemp = dot(surfaceNormal, lightDirection);
    result.cosAngIncidence = max(cosAngIncidenceTemp, 0.f); //clamp it to 0
    float3 halfAngle = normalize(lightDirection + viewDirection);
    float angleNormalHalf = acos(dot(halfAngle, surfaceNormal));
    result.angleNormalHalf = angleNormalHalf;
    
    return result;
}

float3 ComputeLighting(VertexInOut, PerLightData, float4, float4);

float3 ComputeLighting(VertexInOut vert, PerLightData lightData, float4 diffuse, float4 specular) {
    
    AngleNormalHalfResult angleNormalHalfResult = ComputeAngleNormalHalf(vert, lightData);
    
    float exponent = angleNormalHalfResult.angleNormalHalf / specular.w;
    exponent = -(exponent * exponent);
    float gaussianTerm = exp(exponent);
    
    gaussianTerm = angleNormalHalfResult.cosAngIncidence != 0.0f ? gaussianTerm : 0.0;
    
    float3 lighting = diffuse.rgb * angleNormalHalfResult.lightIntensity * angleNormalHalfResult.cosAngIncidence;
    lighting += specular.rgb * angleNormalHalfResult.lightIntensity * gaussianTerm;
    
    return lighting;
}

fragment half4 forwardRendererFragmentShader(VertexInOut inFrag [[stage_in]],
                                             constant LightBlock *lighting [[buffer(0)]],
                                             constant MaterialStruct *material [[buffer(1)]]) {
    float3x3 tangentToCameraSpaceMatrix = float3x3(inFrag.tangentToCameraSpaceMatrixC1, inFrag.tangentToCameraSpaceMatrixC2, inFrag.tangentToCameraSpaceMatrixC3);
    
    if (material->diffuseColour.a < 0.001f) {
        discard_fragment();
    }
    
    float4 diffuse = diffuseColour(material);
    float4 specular = specularColour(material);
    
    float3 totalLighting = diffuse.rgb * lighting->ambientIntensity.rgb;
    
    if (material->ambientColour.a > 0.9f) { // ~= 1
        totalLighting += ambientColour(material).rgb;
    }
    
    for (int light = 0; light < MaxLights; light++) {
        PerLightData lightData = lighting->lights[light];
        if (length_squared(lightData.positionInCameraSpace) == 0) { break; }
        totalLighting += ComputeLighting(inFrag, lightData, diffuse, specular);
    }
    
    return half4(float4(totalLighting.rgb, diffuse.a));
};