shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform sampler2D vertical_gradient;
uniform sampler2D lightning_wave_texture;
uniform sampler2D gradient_color_texture;
uniform float time_elapsed_frac;


void fragment() {
// Input:4
	float n_out4p1 = time_elapsed_frac;


// UVFunc:3
	vec2 n_in3p1 = vec2(0.80000, 1.00000); // vec2(0.0, 1.0); for only upwards (no swirl)
	//vec2 n_out3p0 = vec2(n_out4p1) * n_in3p1 + UV;
	vec2 n_out3p0 = vec2(n_out4p1) * n_in3p1 + UV + vec2(0.0, -0.50);

//	vec2 scroll_offset = vec2(0.0, -1.0);  // Start 1 UV unit below
	//vec2 n_out3p0 = vec2(n_out4p1) * n_in3p1 + UV + scroll_offset;


// Texture2D:2
	vec4 n_out2p0 = texture(lightning_wave_texture, n_out3p0);
	float n_out2p1 = n_out2p0.r;


// Texture2D:8
	vec4 n_out8p0 = texture(gradient_color_texture, vec2(n_out2p1));


// Texture2D:5
	vec4 n_out5p0 = texture(vertical_gradient, UV);


// FloatOp:6
	float n_out6p0 = n_out2p1 * n_out5p0.x;


// Output:0
	ALBEDO = vec3(n_out8p0.xyz);
	ALPHA = n_out6p0;


}
