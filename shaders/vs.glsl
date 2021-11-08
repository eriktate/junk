#version 330 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec2 in_tex_coord;

uniform uint width;
uniform uint height;

out vec2 tex_coord;

vec3 pos;

void main() {
	// re-map pixel coordinates to screen space
	pos = vec3(
		(in_pos.x / width) * 2 - 1,
		-((in_pos.y / width) * 2 - 1),
		in_pos.z
	);

	// pos = vec3(in_pos.x / width, in_pos.y / height, in_pos.z);

	gl_Position = vec4(pos, 1.0);
	// gl_Position = vec4(in_pos, 1.0);
	tex_coord = in_tex_coord;
}
