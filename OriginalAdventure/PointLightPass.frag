#version 330

out vec4 outputColor;

layout(std140) uniform;

uniform Light {
    vec4 positionInCameraSpace;
    vec4 intensity;
    vec3 falloff;
} light;

uniform mat4 cameraToClipMatrix;
uniform vec2 depthRange;
uniform vec2 screenSize;

//Half the size of the near plane {y * aspect, tan(fovy/2.0) } // { 0.7698 , 0.577350 } for fov = pi/3 and aspect = 4:3
uniform vec2 halfSizeNearPlane;

uniform sampler2D diffuseColourSampler;
uniform sampler2D specularColourSampler;

uniform sampler2D normalMapSampler;

uniform sampler2D depthSampler;

vec3 CalcCameraSpacePositionFromWindow(in float windowZ, in vec3 eyeDirection) {
  float ndcZ = (2.0 * windowZ - depthRange.x - depthRange.y) /
    (depthRange.y - depthRange.x);
  float eyeZ = -cameraToClipMatrix[3][2] / ((cameraToClipMatrix[2][3] * ndcZ) - cameraToClipMatrix[2][2]);
  return eyeDirection * eyeZ;
}

float ComputeAttenuation(in vec3 objectPosition,
    in vec3 lightPosition,
    out vec3 lightDirection) {

        vec3 vectorToLight = lightPosition - objectPosition;
        float lightDistanceSqr = dot(vectorToLight, vectorToLight);
        float inverseLightDistance = inversesqrt(lightDistanceSqr);
        lightDirection = vectorToLight * inverseLightDistance;

        return 1 / (light.falloff[0] + light.falloff[1] / inverseLightDistance + light.falloff[2] * lightDistanceSqr);
}

float ComputeAngleNormalHalf(in vec3 cameraSpacePosition, in vec3 surfaceNormal, out float cosAngIncidence, out vec3 lightIntensity) {

    vec3 lightDirection;
    float attenuation = ComputeAttenuation(cameraSpacePosition,
            light.positionInCameraSpace.xyz, lightDirection);
    lightIntensity = attenuation * light.intensity.rgb;

    vec3 viewDirection = normalize(-cameraSpacePosition);

    float cosAngIncidenceTemp = dot(surfaceNormal, lightDirection);
    cosAngIncidence = cosAngIncidenceTemp < 0.0001 ? 0.0f : cosAngIncidenceTemp; //clamp it to 0
    vec3 halfAngle = normalize(lightDirection + viewDirection);
    float angleNormalHalf = acos(dot(halfAngle, surfaceNormal));
    return angleNormalHalf;
}

vec3 ComputeLighting(in vec3 cameraSpacePosition, in vec3 surfaceNormal, in vec3 diffuse, in vec4 specular) {

    vec3 lightIntensity;
    float cosAngIncidence;

    float angleNormalHalf = ComputeAngleNormalHalf(cameraSpacePosition, surfaceNormal, cosAngIncidence, lightIntensity);

    float exponent = angleNormalHalf / specular.a;
    exponent = -(exponent * exponent);
    float gaussianTerm = exp(exponent);

    gaussianTerm = cosAngIncidence != 0.0f ? gaussianTerm : 0.0;

    vec3 lighting = diffuse * lightIntensity * cosAngIncidence;
    lighting += specular.rgb * lightIntensity * gaussianTerm;

    return lighting;
}

vec2 CalcTexCoord() {
   return gl_FragCoord.xy / screenSize;
}

void main() {

    vec2 textureCoordinate = CalcTexCoord();

    vec3 cameraDirection = vec3((2.0 * halfSizeNearPlane * textureCoordinate) - halfSizeNearPlane, -1.0);
    vec3 cameraSpacePosition = CalcCameraSpacePositionFromWindow(texture(depthSampler, textureCoordinate).r, cameraDirection);

	vec3 diffuseColour = texture(diffuseColourSampler, textureCoordinate).rgb;
	vec4 specularColour = texture(specularColourSampler, textureCoordinate);

	vec3 surfaceNormal = texture(normalMapSampler, textureCoordinate).xyz - 1;

    vec3 totalLighting = ComputeLighting(cameraSpacePosition, surfaceNormal, diffuseColour, specularColour);

    outputColor = vec4(totalLighting, 1.f);

}