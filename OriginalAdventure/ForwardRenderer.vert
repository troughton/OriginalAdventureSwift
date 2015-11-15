#version 330

layout(location = 0) in vec4 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 texCoord;
layout(location = 3) in vec4 tangent;

smooth out vec3 vertexNormal;
smooth out vec3 cameraSpacePosition;
smooth out vec2 textureCoordinate;

smooth out mat3 tangentToCameraSpaceMatrix;

uniform mat4 modelToCameraMatrix;
uniform mat4 cameraToClipMatrix;
uniform mat3 normalModelToCameraMatrix;
uniform mat3 nodeToCamera3x3Matrix;

uniform vec2 textureRepeat;

void main() {

    vec4 cameraPos = modelToCameraMatrix * position;
    cameraSpacePosition = cameraPos.xyz;
	gl_Position = cameraToClipMatrix * cameraPos;
	vertexNormal = normalModelToCameraMatrix * normal;
	textureCoordinate = texCoord.st * textureRepeat;

	vec3 mBPrime = tangent.w * (cross(normal, tangent.xyz));

	tangentToCameraSpaceMatrix = mat3(
	          normalize(nodeToCamera3x3Matrix * tangent.xyz),
	          normalize(nodeToCamera3x3Matrix * mBPrime),
	          normalize(nodeToCamera3x3Matrix * normal)
	);
}
