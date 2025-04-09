shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tex_frg_2;
uniform sampler2D tex_frg_7;

void fragment() {
// Texture2D:2
	vec4 n_out2p0 = texture(tex_frg_2, UV);
	float n_out2p1 = n_out2p0.r;


// Texture2D:7
	vec4 n_out7p0 = texture(tex_frg_7, vec2(n_out2p1));


// Input:3
	vec4 n_out3p0 = COLOR;
	float n_out3p1 = n_out3p0.r;


// FloatOp:4
	float n_out4p0 = n_out3p1 * n_out2p1;


// Output:0
	ALBEDO = vec3(n_out7p0.xyz);
	ALPHA = n_out4p0;


}
