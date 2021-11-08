#version 330 core

in vec2 tex_coord;
uniform sampler2D tex;

out vec4 frag_color;

vec2 coord;

void main() {
	ivec2 tex_size = textureSize(tex, 0);
	coord = vec2(
		tex_coord.x / tex_size.x,
		tex_coord.y / tex_size.y
	);

	frag_color = texture(tex, coord);
}
