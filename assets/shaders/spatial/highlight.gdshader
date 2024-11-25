shader_type spatial;
render_mode unshaded;
render_mode depth_draw_always;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec3 highlight_color: source_color = vec3(0.973238, 0.825123, 0.129592);
uniform float blink_frequency = 2.0;

void fragment() {
	vec3 original_color = texture(SCREEN_TEXTURE, SCREEN_UV).xyz;
	float t = (sin(TIME * blink_frequency) * 0.5 + 1.0); // Between 0-1

	// Map from [0, 1] -> [0.1 , 0.2]
	t = t * 0.1 + 0.1;

	// 0.0 = only original
	// 1.0 = only highlight	
	ALBEDO = mix(original_color, highlight_color, t);

	// Modify depth to always draw on top of other stuff
	vec4 ndc = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	DEPTH = (ndc.z / ndc.w) + 0.001;

	// This is roughly 1m above ground
	//DEPTH = (ndc.z / ndc.w) + 0.00005;
}

