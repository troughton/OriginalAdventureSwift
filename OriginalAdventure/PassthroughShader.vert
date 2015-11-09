#version 330

layout(location = 0) in vec4 position;

uniform mat4 modelToCameraMatrix;
uniform mat4 cameraToClipMatrix;
uniform mat3 normalModelToCameraMatrix;

void main() {

    vec4 cameraPos = modelToCameraMatrix * position;
	gl_Position = cameraToClipMatrix * cameraPos;
}
