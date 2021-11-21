#version 450 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec2 in_tex_coord;
layout (location = 2) in uint in_tex_id;

uniform uint width;
uniform uint height;

out uint tex_id;
out vec2 tex_coord;

vec3 pos;

void main() {
	// re-map pixel coordinates to screen space
	pos = vec3(
		(in_pos.x / width) * 2 - 1,
		-((in_pos.y / width) * 2 - 1),
		in_pos.z
	);

	gl_Position = vec4(pos, 1.0);
	tex_coord = in_tex_coord;
	tex_id = in_tex_id;
}
