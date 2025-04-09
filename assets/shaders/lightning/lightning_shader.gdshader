shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform sampler2D lightning_texture;
uniform sampler2D gradient_color_texture;
uniform float time_elapsed_frac;


void fragment() {
// Input:4
	float n_out4p0 = TIME;


// VectorOp:5
	vec2 n_in5p1 = vec2(0.00000, -0.20000);
	vec2 n_out5p0 = vec2(n_out4p0) * n_in5p1;


// UVFunc:3
	vec2 n_in3p1 = vec2(1.00000, 1.00000);
	vec2 n_out3p0 = n_out5p0 * n_in3p1 + UV;


// Texture2D:2
	vec4 n_out2p0 = texture(lightning_texture, n_out3p0);
	float n_out2p1 = n_out2p0.r;


// SmoothStep:6
	//float n_in6p0 = 0.20000;
	//float lifetime_offset = 0.5;
	//float lifetime_frac = clamp((TIME - spawn_time) / max_lifetime, 0.0, 1.0);
	//float lifetime_frac = smoothstep(spawn_time + max_lifetime, spawn_time, TIME);
	float lower = mix(0.0, 1.0, time_elapsed_frac); //mix(lifetime_offset, lifetime_frac, 1.0);
	float upper = 1.00000;
	float n_out6p0 = smoothstep(lower, upper, n_out2p1);


// Texture2D:9
	vec4 n_out9p0 = texture(gradient_color_texture, vec2(n_out6p0));


// Output:0
	ALBEDO = vec3(n_out9p0.xyz);
	ALPHA = n_out6p0;


}
