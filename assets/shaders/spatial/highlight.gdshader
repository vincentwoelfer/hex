shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
//uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
//uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_linear_mipmap;

uniform vec3 highlight_color: source_color;
uniform float blink_speed = 4.0;
instance uniform float enabled = 0.0;

void fragment() {
	vec3 original_color = texture(SCREEN_TEXTURE, SCREEN_UV).xyz;
	float t = (sin(TIME * blink_speed) * 0.5 + 1.0); // Between 0-1
	// Between 0.0 - 0.2
	t = enabled * t * 0.5;

	// 0.0 = only highlight
	// 1.0 = only original
	ALBEDO = mix(original_color, highlight_color, t);
}

// const float fib = 1123.581321;
// const float phi = 1161.803398;
// const float tau = 3142.592653;
// const vec2 magic = vec2(fib, phi);

// float random(vec2 uv) {
// 	return fract(sin(dot(uv.xy, magic)) * tau);
// }

// void vertex() {
// 	VERTEX.y += random(texture(SCREEN_TEXTURE, vec2(TIME*5.4353,-TIME*VERTEX.x*13.123)).xy);
// }
