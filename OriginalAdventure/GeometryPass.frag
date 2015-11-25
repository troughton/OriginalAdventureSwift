#version 330

smooth in vec3 vertexNormal;
smooth in vec2 textureCoordinate;
smooth in vec3 cameraSpacePosition;

smooth in mat3 tangentToCameraSpaceMatrix;

layout (location = 0) out vec3 vertexNormalOut;
layout (location = 1) out vec4 diffuseColourOut;
layout (location = 2) out vec4 specularColourOut;
layout (location = 3) out vec3 ambientColourOut;


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
											
void main()									
{
    vec4 diffuseColour = diffuseColour();
    vec4 ambientColour = ambientColour();
    if (diffuseColour.a < 0.001f) {
       discard;
    }

    vec3 cameraSpaceNormal;
    if (useNormalMap()) {
        cameraSpaceNormal = normalize(tangentToCameraSpaceMatrix * (texture(normalMapSampler, textureCoordinate).rgb*2.0 - 1.0));
    } else {
        cameraSpaceNormal = normalize(vertexNormal);
    }

    vertexNormalOut = cameraSpaceNormal + 1;

    diffuseColourOut = diffuseColour;

    if (ambientColour.a == 1) { // ~= 1
        ambientColourOut = ambientColour.rgb;
    }

    specularColourOut = vec4(specularColour());
}
