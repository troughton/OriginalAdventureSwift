#version 330

smooth in vec3 vertexNormal;
smooth in vec2 textureCoordinate;
smooth in vec3 cameraSpacePosition;

smooth in mat3 tangentToCameraSpaceMatrix;

out vec4 outputColor;

layout(std140) uniform;

struct PerLightData {
    vec4 positionInCameraSpace;
    vec4 lightIntensity;
    vec3 falloff;
};

const int MaxLights = 32;

uniform LightBlock {
    vec4 ambientIntensity;
    PerLightData lights[MaxLights];
} lighting;

uniform Material {
    vec4 ambientColour; //of which xyz are the colour and w is a 0/1 as to whether ambient self-illumination is enabled.
    vec4 diffuseColour; //r,g,b,a
    vec4 specularColour; //of which xyz are the colour and w is the specularity.
} material;

uniform sampler2D ambientColourSampler;
uniform sampler2D diffuseColourSampler;
uniform sampler2D specularitySampler;
uniform sampler2D normalMapSampler;

vec4 diffuseColour() {
    if (isnan(material.diffuseColour.x)) {
        return texture(diffuseColourSampler, textureCoordinate);
    } else {
        return material.diffuseColour;
    }
}

vec4 ambientColour() {
    
    if (isnan(material.ambientColour.x)) {
        return texture(ambientColourSampler, textureCoordinate);
    } else {
        return material.ambientColour;
    }
}

vec4 specularColour() {
    if (isnan(material.specularColour.x)) {
        return texture(specularitySampler, textureCoordinate);
    } else {
        return material.specularColour;
    }
}

bool useNormalMap() {
    return isnan(material.diffuseColour.y); //require that textures have a diffuse map if they have a normal map
}

float ComputeAttenuation(in vec3 objectPosition,
                         in vec3 lightPosition,
                         in vec3 falloff,
                         out vec3 lightDirection) {
    
    vec3 vectorToLight = lightPosition - objectPosition;
    float lightDistanceSqr = dot(vectorToLight, vectorToLight);
    float inverseLightDistance = inversesqrt(lightDistanceSqr);
    lightDirection = vectorToLight * inverseLightDistance;
    
    return 1 / (falloff.x + falloff.y / inverseLightDistance + falloff.z * lightDistanceSqr);
}


float ComputeAngleNormalHalf(in PerLightData lightData, out float cosAngIncidence, out vec3 lightIntensity) {
    vec3 lightDirection;
    if (lightData.positionInCameraSpace.w < 0.0001) { //DirectionalLight
        lightDirection = lightData.positionInCameraSpace.xyz;
        lightIntensity = lightData.lightIntensity.rgb;
    }
    else {
        float attenuation = ComputeAttenuation(cameraSpacePosition,
                                               lightData.positionInCameraSpace.xyz, lightData.falloff, lightDirection);
        lightIntensity = attenuation * lightData.lightIntensity.rgb;
    }
    vec3 viewDirection = normalize(-cameraSpacePosition);
    vec3 surfaceNormal;
    if (useNormalMap()) {
        surfaceNormal = normalize(tangentToCameraSpaceMatrix * (texture(normalMapSampler, textureCoordinate).rgb*2.0 - 1.0));
    } else {
        surfaceNormal = normalize(vertexNormal);
    }
    
    float cosAngIncidenceTemp = dot(surfaceNormal, lightDirection);
    cosAngIncidence = cosAngIncidenceTemp < 0.0001 ? 0 : cosAngIncidenceTemp; //clamp it to 0
    vec3 halfAngle = normalize(lightDirection + viewDirection);
    float angleNormalHalf = acos(dot(halfAngle, surfaceNormal));
    return angleNormalHalf;
}

vec3 ComputeLighting(in PerLightData lightData, in vec4 diffuse, in vec4 specular) {
    vec3 lightIntensity;
    float cosAngIncidence;
    
    float angleNormalHalf = ComputeAngleNormalHalf(lightData, cosAngIncidence, lightIntensity);
    
    float exponent = angleNormalHalf / specular.w;
    exponent = -(exponent * exponent);
    float gaussianTerm = exp(exponent);
    
    gaussianTerm = cosAngIncidence != 0.0f ? gaussianTerm : 0.0;
    
    vec3 lighting = diffuse.rgb * lightIntensity * cosAngIncidence;
    lighting += specular.rgb * lightIntensity * gaussianTerm;
    
    return lighting;
}

void main() {
    
    if (material.diffuseColour.a < 0.001f) {
        outputColor = vec4(0);
        return;
    }
    
    vec4 diffuse = diffuseColour();
    vec4 specular = specularColour();
    
    vec3 totalLighting = diffuse.rgb * lighting.ambientIntensity.rgb;
    
    if (material.ambientColour.a > 0.9f) { // ~= 1
        totalLighting += ambientColour().rgb;
    }
    
    for (int light = 0; light < MaxLights; light++) {
        PerLightData lightData = lighting.lights[light];
        if (lightData.positionInCameraSpace == vec4(0)) { break; }
        totalLighting += ComputeLighting(lightData, diffuse, specular);
    }
    
    outputColor = vec4(totalLighting, diffuse.a);
    
}