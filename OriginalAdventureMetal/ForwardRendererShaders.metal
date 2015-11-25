//
//  Shaders.metal
//  OriginalAdventureMetal
//
//  Created by Thomas Roughton on 22/11/15.
//  Copyright (c) 2015 Thomas Roughton. All rights reserved.
//

#include <metal_stdlib>
#include "Structs.h"
#include "MetalStructs.h"

using namespace metal;
using namespace Ingenero;

struct VertexInput {
    packed_float3 position;
    packed_float3 normal;
    packed_float2 textureCoordinate;
};

vertex VertexInOut forwardRendererVertexShader(uint vid [[ vertex_id ]],
                                    device VertexInput *positionData  [[ buffer(0) ]],
                                     device packed_float3* tangent  [[ buffer(1) ]],
                                    constant ModelMatrices *matrices [[buffer(2)]]) {
    VertexInOut outVertex;
    
    VertexInput input = positionData[vid];
    float4 cameraSpacePosition = matrices->modelToCameraMatrix * float4(input.position, 1);
    outVertex.cameraSpacePosition = cameraSpacePosition.xyz;
    outVertex.position = matrices->projectionMatrix * cameraSpacePosition;
    outVertex.textureCoordinate = input.textureCoordinate * matrices->textureRepeat.xy;
    outVertex.normal = half3(matrices->normalModelToCameraMatrix * float3(input.normal));
    
    float3 mBPrime = cross(input.normal, tangent[vid]);
    
    outVertex.tangentToCameraSpaceMatrixC1 = half3(normalize(matrices->modelToCameraRotationMatrix * float3(tangent[vid])));
    outVertex.tangentToCameraSpaceMatrixC2 = half3(normalize(matrices->modelToCameraRotationMatrix * mBPrime));
    outVertex.tangentToCameraSpaceMatrixC3 = half3(normalize(matrices->modelToCameraRotationMatrix * float3(input.normal)));
    
    return outVertex;
};

struct AttenuationResult {
    float3 lightDirection;
    float attenuation;
};

constexpr sampler s = sampler(coord::normalized,
                              address::repeat,
                              filter::linear,
                              mip_filter::linear);

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


AngleNormalHalfResult ComputeAngleNormalHalf(VertexInOut, half3, PerLightData);

AngleNormalHalfResult ComputeAngleNormalHalf(VertexInOut vert, half3 surfaceNormal, PerLightData lightData) {
    half3 lightDirection;
    AngleNormalHalfResult result;
    
    if (lightData.positionInCameraSpace.w < 0.0001) { //DirectionalLight
        lightDirection = half3(lightData.positionInCameraSpace.xyz);
        result.lightIntensity = lightData.intensity.rgb;
    }
    else {
        AttenuationResult attenuationResult = ComputeAttenuation(vert.cameraSpacePosition,
                                               lightData.positionInCameraSpace.xyz, lightData.falloff.xyz);
        lightDirection = half3(attenuationResult.lightDirection);
        result.lightIntensity = attenuationResult.attenuation * lightData.intensity.rgb;
    }
    half3 viewDirection = half3(normalize(-vert.cameraSpacePosition));
    
    float cosAngIncidenceTemp = dot(surfaceNormal, lightDirection);
    result.cosAngIncidence = max(cosAngIncidenceTemp, 0.f); //clamp it to 0
    half3 halfAngle = normalize(lightDirection + viewDirection);
    float angleNormalHalf = acos(dot(halfAngle, surfaceNormal));
    result.angleNormalHalf = angleNormalHalf;
    
    return result;
}

float3 ComputeLighting(VertexInOut, PerLightData, half3, float4, half4);

float3 ComputeLighting(VertexInOut vert, PerLightData lightData, half3 surfaceNormal, float4 diffuse, half4 specular) {
    
    AngleNormalHalfResult angleNormalHalfResult = ComputeAngleNormalHalf(vert, surfaceNormal, lightData);
    
    float exponent = angleNormalHalfResult.angleNormalHalf / float(specular.w);
    exponent = -(exponent * exponent);
    float gaussianTerm = exp(exponent);
    
    gaussianTerm = angleNormalHalfResult.cosAngIncidence != 0.0f ? gaussianTerm : 0.0;
    
    float3 lighting = diffuse.rgb * angleNormalHalfResult.lightIntensity * angleNormalHalfResult.cosAngIncidence;
    lighting += float3(specular.rgb) * angleNormalHalfResult.lightIntensity * gaussianTerm;
    
    return lighting;
}

fragment half4 forwardRendererFragmentShader(VertexInOut inFrag [[stage_in]],
                                             constant LightBlock *lighting [[buffer(0)]],
                                             texture2d<half> ambientTexture [[texture(0)]],
                                             texture2d<float> diffuseTexture [[texture(1)]],
                                             texture2d<half> specularTexture [[texture(2)]],
                                             texture2d<half> normalTexture [[texture(3)]]) {
    half3x3 tangentToCameraSpaceMatrix = half3x3(inFrag.tangentToCameraSpaceMatrixC1, inFrag.tangentToCameraSpaceMatrixC2, inFrag.tangentToCameraSpaceMatrixC3);
    
    float2 textureCoordinate = inFrag.textureCoordinate;

    float4 diffuse = diffuseTexture.sample(s, textureCoordinate);
    
    if (diffuse.a < 0.001f) {
        return half4(0, 0, 0, 0);
    }
    
    half4 specular = specularTexture.sample(s, textureCoordinate);
    half4 ambientColour = ambientTexture.sample(s, textureCoordinate);
    half4 localSpaceNormal = normalTexture.sample(s, textureCoordinate) * 2 - 1;
    half3 surfaceNormal = normalize(tangentToCameraSpaceMatrix * localSpaceNormal.xyz);
    
    float3 totalLighting = diffuse.rgb * lighting->ambientIntensity.rgb;
    
    if (abs(ambientColour.a - 1) < 0.01) { // ~= 1
        totalLighting += float3(ambientColour.rgb);
    }
    
    for (int light = 0; light < MaxLights; light++) {
        PerLightData lightData = lighting->lights[light];
        if (length_squared(lightData.positionInCameraSpace) == 0) { break; }
        totalLighting += ComputeLighting(inFrag, lightData, surfaceNormal, diffuse, specular);
    }
    
    return half4(float4(totalLighting, diffuse.a));
};