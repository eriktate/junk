#version 450 core

flat in uint tex_id;
in vec2 tex_coord;
uniform sampler2D tex0;
uniform sampler2D tex1;

out vec4 frag_color;

vec2 coord;

void main() {
	if (tex_id == 0) {
		ivec2 tex_size = textureSize(tex0, 0);
		coord = vec2(
			tex_coord.x / tex_size.x,
			tex_coord.y / tex_size.y
		);
		frag_color = texture(tex0, coord);
	}

	if (tex_id == 1) {
		ivec2 tex_size = textureSize(tex1, 0);
		coord = vec2(
			tex_coord.x / tex_size.x,
			tex_coord.y / tex_size.y
		);
		frag_color = texture(tex1, coord);
	}
}
