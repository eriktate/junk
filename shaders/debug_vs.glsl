#version 450 core
layout (location = 0) in vec3 in_pos;
// layout (location = 1) in vec4 in_color;

uniform uint width;
uniform uint height;

// out vec3 color;

vec3 pos;

void main() {
	// re-map pixel coordinates to screen space
	pos = vec3(
		(in_pos.x / width) * 2 - 1,
		-((in_pos.y / width) * 2 - 1),
		in_pos.z
	);

	gl_Position = vec4(pos, 1.0);
	// out_color = color;
}
